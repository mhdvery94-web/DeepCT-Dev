"""Executable staging build preflight contract, without Android downloads."""
import importlib.util
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('staging_android', ROOT / 'scripts/check-staging-android.py')
check = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check)


@pytest.mark.parametrize('branch', ['develop', 'staging'])
def test_selected_preview_api_allowed(branch):
    assert check.validate(f'refs/heads/{branch}', 'https://preview.example.test/api/', ['https://prod.example.test/api']) == 'https://preview.example.test/api'


@pytest.mark.parametrize('ref', ['refs/heads/main', 'refs/tags/v1', 'refs/heads/feature', 'staging', 'refs/pull/1/merge'])
def test_other_refs_rejected(ref):
    with pytest.raises(ValueError):
        check.validate(ref, 'https://preview.example.test/api', [])


@pytest.mark.parametrize('url', ['', 'http://preview.example.test/api', 'https://preview.example.test',
    'https://user:secret@preview.example.test/api', 'https://preview.example.test/api?token=secret',
    'https://preview.example.test/api#fragment', 'https://prod.example.test/api',
    'https://prod.example.test/other/api', 'https://zestfully-usable-pledge.ngrok-free.dev/api',
    'https://api.brin.fajrianhost.my.id/api', 'https://localhost/api', 'https://127.0.0.1/api'])
def test_unsafe_or_production_api_rejected(url):
    with pytest.raises(ValueError):
        check.validate('refs/heads/staging', url, ['https://prod.example.test/api'])


def test_workflow_isolated_and_build_depends_on_checks():
    text = (ROOT / '.github/workflows/staging-android.yml').read_text()
    assert "branches: [staging]" in text
    assert "paths: ['.github/workflows/staging-android.yml']" in text
    assert 'needs: [preflight, test, test-model-cpu]' in text
    assert "FLUTTER_VERSION: '3.44.9'" in text
    assert 'ORG_GRADLE_PROJECT_deepctStaging' in text
    assert 'flutter build apk --debug' in text
    assert 'contents: write' not in text
    assert 'secrets.' not in text
    assert 'workflow_dispatch:' in text


def test_manifest_and_gradle_support_isolated_identity():
    gradle = (ROOT / 'fe/android/app/build.gradle.kts').read_text()
    manifest = (ROOT / 'fe/android/app/src/main/AndroidManifest.xml').read_text()
    assert 'deepctStaging' in gradle
    assert 'id.go.brin.neutronct.staging' in gradle
    assert 'deepCT-AI Staging' in gradle
    assert 'android:label="${deepctAppLabel}"' in manifest


@pytest.mark.parametrize('branch', ['develop', 'staging'])
def test_existing_shared_host_branch_prefix_is_allowed(branch):
    host = 'https://zestfully-usable-pledge.ngrok-free.dev'
    assert check.validate(f'refs/heads/{branch}', f'{host}/{branch}/api', [f'{host}/api']) == f'{host}/{branch}/api'


@pytest.mark.parametrize('path', ['/api', '/other/api', '/develop/api', '/staging/../api', '/staging/%2e%2e/api',
    '/staging%2fapi', '/staging//api', '/staging/api//', '/staging/api\n'])
def test_shared_host_wrong_or_malformed_prefix_rejected(path):
    with pytest.raises(ValueError):
        check.validate('refs/heads/staging', 'https://zestfully-usable-pledge.ngrok-free.dev' + path, [])


@pytest.mark.parametrize('url', ['https://zestfully-usable-pledge.ngrok-free.dev./api', 'https://%7aestfully-usable-pledge.ngrok-free.dev/api'])
def test_alternate_production_host_spelling_cannot_bypass_guard(url):
    with pytest.raises(ValueError):
        check.validate('refs/heads/staging', url, [])
