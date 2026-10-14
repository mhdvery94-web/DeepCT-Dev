import hashlib
import json

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from test_api import settings

MGMT = {'Authorization': 'Bearer test-management-token'}


@pytest.fixture
def upload_client(model_tree):
    root, activation, directory, manifest = model_tree
    data = (directory / 'model.h5').read_bytes()
    app = create_app(settings(root, activation))
    return TestClient(app), app, dict(manifest, version='2.0.0'), data


def begin(client, manifest):
    response = client.post('/management/uploads', json=manifest, headers=MGMT)
    assert response.status_code == 201, response.text
    return response.json()


def put(client, session, data, offset=0, token=None):
    return client.put('/uploads/' + session['id'], content=data, headers={
        'Authorization': 'Bearer ' + (token or session['token']),
        'Upload-Offset': str(offset), 'Content-Type': 'application/octet-stream'})


def action(client, session, name):
    response = client.post('/management/uploads/' + session['id'] + '/' + name, headers=MGMT)
    if response.status_code == 202:
        return client.get('/management/uploads/' + session['id'], headers=MGMT)
    return response


def test_management_auth_and_strict_manifest(upload_client):
    client, _, manifest, _ = upload_client
    for auth in [{}, {'Authorization': 'Bearer test-inference-token'}]:
        assert client.post('/management/uploads', json=manifest, headers=auth).status_code == 401
    for extra in [{'path': '/tmp/evil'}, {'adapter': 'custom'}, {'size_bytes': 10 * 1024**3 + 1}]:
        assert client.post('/management/uploads', json=manifest | extra, headers=MGMT).status_code == 422


def test_capability_scope_expiry_offset_and_cancel(upload_client):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    other = begin(client, manifest | {'version': '3.0.0'})
    assert put(client, session, data, token=other['token']).status_code == 401
    assert put(client, session, data, token='wrong').status_code == 401
    assert put(client, session, data, offset=1).status_code == 409
    app.state.uploads.clock = lambda: session['expires_at'] + 1
    assert put(client, session, data).status_code == 401
    renewed = action(client, session, 'renew').json()
    assert renewed['expires_at'] == session['expires_at'] + 901
    assert put(client, renewed, data).json()['state'] == 'uploaded'
    assert action(client, session, 'cancel').json()['state'] == 'cancelled'
    assert action(client, session, 'finalize').status_code == 409


def test_restart_resume_and_atomic_publish_separate_activation(upload_client):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    assert put(client, session, data[:100]).json()['offset'] == 100
    restarted = create_app(settings(app.state.registry.root, app.state.registry.activation_file))
    client = TestClient(restarted)
    assert put(client, session, data[100:], offset=100).json()['state'] == 'uploaded'
    assert action(client, session, 'finalize').json()['state'] == 'ready_for_test'
    assert action(client, session, 'activate').status_code == 409
    assert action(client, session, 'test').json()['last_error'] == 'unavailable'
    assert action(client, session, 'publish').status_code == 409
    restarted.state.uploads.compatibility = lambda directory: None
    assert action(client, session, 'test').json()['state'] == 'ready_for_activate'
    assert action(client, session, 'publish').json()['published'] is True
    assert restarted.state.registry.active_versions() == set()
    assert action(client, session, 'publish').status_code == 200
    assert client.post('/management/uploads', json=manifest, headers=MGMT).status_code == 409
    assert action(client, session, 'activate').json()['state'] == 'active'
    assert manifest['version'] in {v for _, v in restarted.state.registry.active_versions()}


def test_checksum_and_format_are_real_guards(upload_client):
    client, _, manifest, data = upload_client
    session = begin(client, manifest | {'sha256': '0' * 64})
    assert put(client, session, data).status_code == 200
    assert action(client, session, 'finalize').json()['state'] == 'failed'
    assert client.get('/management/uploads/' + session['id'], headers=MGMT).json()['state'] == 'failed'
    bad = b'not a model'
    session = begin(client, manifest | {'version': '3.0.0', 'size_bytes': len(bad), 'sha256': hashlib.sha256(bad).hexdigest()})
    put(client, session, bad)
    assert action(client, session, 'finalize').json()['state'] == 'failed'


def test_size_disk_reservations_and_duplicate_session(upload_client):
    client, app, manifest, data = upload_client
    app.state.uploads.free_bytes = lambda: 2 * 1024**3 + len(data) * 2 - 1
    session = begin(client, manifest)
    assert client.post('/management/uploads', json=manifest, headers=MGMT).status_code == 409
    assert client.post('/management/uploads', json=manifest | {'version': '3.0.0'}, headers=MGMT).status_code == 507
    assert put(client, session, data + b'x').status_code == 413
    assert put(client, session, b'x' * (4 * 1024**2 + 1)).status_code == 413
    app.state.uploads.free_bytes = lambda: 0
    assert put(client, session, data).status_code == 507


def test_restart_ignores_uncommitted_session_directory_and_truncates_tail(upload_client):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    assert put(client, session, data[:100]).json()['offset'] == 100
    path = app.state.uploads.path(session['id']) / 'candidate' / 'model.h5'
    with path.open('ab') as handle:
        handle.write(b'uncommitted tail')
    (app.state.uploads.root / '22222222-2222-4222-8222-222222222222').mkdir()
    restarted = create_app(settings(app.state.registry.root, app.state.registry.activation_file))
    assert path.stat().st_size == 100
    client = TestClient(restarted)
    assert put(client, session, data[100:], offset=100).status_code == 200
    assert begin(client, manifest | {'version': '3.0.0'})['state'] == 'uploading'


def test_status_recovers_activation_file_committed_before_session_metadata(upload_client):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    put(client, session, data)
    action(client, session, 'finalize')
    app.state.uploads.compatibility = lambda directory: None
    action(client, session, 'test')
    action(client, session, 'publish')
    activation = app.state.registry.activation_file
    activation.parent.mkdir(parents=True, exist_ok=True)
    activation.write_text(json.dumps({'active': [{'model_id': manifest['model_id'], 'version': '2.0.0'}]}))
    assert client.get('/management/uploads/' + session['id'], headers=MGMT).json()['state'] == 'active'
    activation.write_text('{"active": []}')
    assert client.get('/management/uploads/' + session['id'], headers=MGMT).json()['state'] == 'ready_for_activate'


def test_lost_create_response_replays_exact_intent_after_restart(upload_client):
    client, app, manifest, data = upload_client
    intent = '11111111-1111-4111-8111-111111111111'
    headers = MGMT | {'Idempotency-Key': intent}
    first = client.post('/management/uploads', json=manifest, headers=headers).json()
    assert put(client, first, data[:100]).status_code == 200
    restarted = create_app(settings(app.state.registry.root, app.state.registry.activation_file))
    client = TestClient(restarted)
    restarted.state.uploads.free_bytes = lambda: 0
    replay = client.post('/management/uploads', json=manifest, headers=headers)
    assert replay.status_code == 201, replay.text
    assert replay.json()['id'] == first['id']
    assert replay.json()['offset'] == 100
    assert len(list(restarted.state.uploads.sessions())) == 1
    assert client.post('/management/uploads', json=manifest | {'name': 'changed'}, headers=headers).status_code == 409
    assert client.post('/management/uploads', json=manifest, headers=MGMT | {'Idempotency-Key': '22222222-2222-4222-8222-222222222222'}).status_code == 409


def test_availability_revisions_ignore_delayed_old_targets(upload_client):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    put(client, session, data)
    action(client, session, 'finalize')
    app.state.uploads.compatibility = lambda _: None
    action(client, session, 'test')
    action(client, session, 'publish')
    path = '/management/uploads/' + session['id']
    assert client.post(path + '/activate', json={'revision': 1}, headers=MGMT).json()['state'] == 'active'
    assert client.post(path + '/activate', json={'revision': 1}, headers=MGMT).json()['state'] == 'active'
    assert client.post(path + '/deactivate', json={'revision': 1}, headers=MGMT).status_code == 409
    assert client.post(path + '/deactivate', json={'revision': 2}, headers=MGMT).json()['state'] == 'ready_for_activate'
    assert client.post(path + '/activate', json={'revision': 1}, headers=MGMT).json()['state'] == 'ready_for_activate'
    assert app.state.registry.active_versions() == set()


def test_availability_revision_survives_restart_before_activation_commit(upload_client, monkeypatch):
    import app.uploads as module
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    put(client, session, data)
    action(client, session, 'finalize')
    app.state.uploads.compatibility = lambda _: None
    action(client, session, 'test')
    action(client, session, 'publish')
    path = '/management/uploads/' + session['id']
    assert client.post(path + '/activate', json={'revision': 1}, headers=MGMT).status_code == 200
    write = module.atomic_json
    def fail_activation(target, payload):
        if target == app.state.registry.activation_file:
            raise OSError('interrupted before activation commit')
        write(target, payload)
    monkeypatch.setattr(module, 'atomic_json', fail_activation)
    with pytest.raises(OSError):
        client.post(path + '/deactivate', json={'revision': 2}, headers=MGMT)
    monkeypatch.setattr(module, 'atomic_json', write)
    restarted = create_app(settings(app.state.registry.root, app.state.registry.activation_file))
    client = TestClient(restarted)
    assert client.post(path + '/deactivate', json={'revision': 2}, headers=MGMT).json()['state'] == 'ready_for_activate'
    assert client.post(path + '/activate', json={'revision': 1}, headers=MGMT).json()['state'] == 'ready_for_activate'
    assert client.post(path + '/activate', headers=MGMT).status_code == 409
    assert restarted.state.registry.active_versions() == set()


def test_availability_revision_requires_integer_not_boolean(upload_client):
    client, _, manifest, _ = upload_client
    session = begin(client, manifest)
    path = '/management/uploads/' + session['id'] + '/activate'
    assert client.post(path, json={'revision': True}, headers=MGMT).status_code == 422
