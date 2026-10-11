import json
import shutil
import sys

import pytest

from app.registry import Registry, RegistryError
from conftest import activate


def test_catalog_compatible_identity_without_loading_weights_or_tensorflow(model_tree, monkeypatch):
    root, activation, directory, _ = model_tree
    def forbidden(*args, **kwargs):
        pytest.fail('catalog opened weights')
    import h5py
    monkeypatch.setattr(h5py, 'File', forbidden)
    registry = Registry(root, activation)
    catalog = registry.catalog()
    assert catalog['count'] == 1
    assert catalog['models'][0] == {
        'name': 'ginet-tcd-revisi-v1-0-0', 'display_name': 'GINet TC-D Revisi',
        'description': 'Imported test fixture', 'model_id': 'ginet-tcd-revisi',
        'version': '1.0.0', 'file': 'model.h5',
        'endpoint': '/predict/ginet-tcd-revisi/1.0.0', 'active': False,
    }
    assert 'tensorflow' not in sys.modules
    activate(activation)
    assert registry.catalog()['models'][0]['active'] is True


@pytest.mark.parametrize('update', [
    {'model_id': '../escape'}, {'version': '1.0'}, {'version': '01.0.0'},
    {'version': '1.0.0-rc1'}, {'weight_file': '../model.h5'},
    {'weight_file': 'model.pkl'}, {'weight_file': 'script.py'},
    {'framework': 'pytorch'}, {'adapter': 'unknown'}, {'sha256': 'x' * 64},
    {'schema_version': 2}, {'schema_version': True}, {'size_bytes': 0}, {'name': ''}, {'surprise': True},
    {'input': {'width': 1024.0, 'height': 1024, 'dtype': 'uint16', 'time_scalar': 0.5}},
    {'input': {'width': 1024, 'height': 1024, 'dtype': 'uint16', 'time_scalar': 0.6}},
])
def test_rejects_invalid_manifest(model_tree, update):
    root, activation, directory, manifest = model_tree
    manifest.update(update)
    (directory / 'manifest.json').write_text(json.dumps(manifest))
    with pytest.raises(RegistryError):
        Registry(root, activation).catalog()


def test_rejects_duplicate_identity_and_existing_publish_target(model_tree):
    root, activation, directory, _ = model_tree
    registry = Registry(root, activation)
    with pytest.raises(RegistryError):
        registry.assert_version_available('ginet-tcd-revisi', '1.0.0')
    shutil.copytree(directory, directory.parent / '2.0.0')
    with pytest.raises(RegistryError):
        registry.catalog()


@pytest.mark.parametrize('target', ['weights', 'manifest', 'version'])
def test_rejects_symlinked_registry_content(model_tree, target, tmp_path):
    root, activation, directory, _ = model_tree
    path = {'weights': directory / 'model.h5', 'manifest': directory / 'manifest.json', 'version': directory}[target]
    moved = tmp_path / ('moved-' + path.name)
    path.rename(moved)
    path.symlink_to(moved, target_is_directory=target == 'version')
    with pytest.raises(RegistryError):
        Registry(root, activation).catalog()


def test_integrity_seam_refuses_changed_weight_bytes(model_tree):
    root, activation, directory, _ = model_tree
    registry = Registry(root, activation)
    registry.validate_candidate(directory)
    with (directory / 'model.h5').open('ab') as handle:
        handle.write(b'tampered')
    with pytest.raises(RegistryError):
        registry.validate_candidate(directory)


def test_activation_must_live_outside_immutable_root(model_tree):
    root, _, _, _ = model_tree
    with pytest.raises(RegistryError):
        Registry(root, root / 'active.json')


def test_staging_rejects_extra_executable_content(model_tree):
    root, activation, directory, _ = model_tree
    (directory / 'custom.py').write_text('raise RuntimeError("must never run")')
    with pytest.raises(RegistryError):
        Registry(root, activation).validate_candidate(directory)


def test_duplicate_json_keys_are_rejected(model_tree):
    root, activation, directory, _ = model_tree
    path = directory / 'manifest.json'
    path.write_text(path.read_text().replace('"schema_version": 1', '"schema_version": 1, "schema_version": 1'))
    with pytest.raises(RegistryError):
        Registry(root, activation).catalog()
