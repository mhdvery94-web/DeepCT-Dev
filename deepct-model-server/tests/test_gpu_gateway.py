"""CPU boundary tests: real HTTP transport, file locks and child processes."""
import asyncio
import json
import multiprocessing
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.registry import Registry
from conftest import activate

AUTH = {'Authorization': 'Bearer assistant-test-token'}
PAYLOAD = {'model': 'deepseek-r1:7b', 'messages': [{'role': 'user', 'content': 'trusted metadata?'}],
           'stream': False, 'keep_alive': 0, 'options': {'num_ctx': 16384, 'num_predict': 2048}}


def configured(tmp_path, **extra):
    return Settings(tmp_path / 'models', tmp_path / 'active.json', 'inference-test', 'management-test',
        **{'assistant_token': 'assistant-test-token', 'gpu_lease_path': tmp_path / 'gpu.lock',
           'assistant_gpu_bytes': 1024, 'assistant_timeout_seconds': 2,
           'assistant_cleanup_seconds': .15, **extra})


@pytest.fixture
def gpu_probe(tmp_path, monkeypatch):
    binary = tmp_path / 'nvidia-smi'
    binary.write_text('#!/bin/sh\necho 8192\n')
    binary.chmod(0o700)
    import os
    monkeypatch.setenv('PATH', str(tmp_path) + ':' + os.environ['PATH'])


@pytest.fixture
def provider(monkeypatch):
    state = {'requests': [], 'resident': False, 'block': None, 'entered': threading.Event(),
             'failure': None, 'response_extra': {}, 'disconnect': False, 'unload_failure': False, 'cleanup_lock_check': None}
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass
        def do_GET(self):
            assert self.path == '/api/ps'
            data = {'models': [{'name': 'deepseek-r1:7b'}] if state['resident'] else []}
            self.reply(200, data)
        def reply(self, status, data):
            raw = json.dumps(data).encode()
            self.send_response(status)
            self.send_header('Content-Length', str(len(raw)))
            self.end_headers()
            try:
                self.wfile.write(raw)
            except (BrokenPipeError, ConnectionResetError):
                pass
        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            state['requests'].append((self.path, body))
            if self.path == '/api/generate':
                if state['cleanup_lock_check']:
                    state['cleanup_lock_check']()
                if state['unload_failure']:
                    return self.reply(500, {'error': 'private provider path'})
                state['resident'] = False
                return self.reply(200, {'model': 'deepseek-r1:7b', 'done': True})
            assert self.path == '/api/chat'
            state['resident'] = True
            state['entered'].set()
            if state['block']:
                state['block'].wait(5)
            if state['disconnect']:
                import socket
                self.connection.shutdown(socket.SHUT_RDWR)
                self.connection.close()
                return
            if state['failure']:
                return self.reply(500, {'error': 'private prompt and bearer-secret'})
            self.reply(200, {'model': 'deepseek-r1:7b', 'message': {'role': 'assistant',
                'thinking': 'PRIVATE REASONING', 'content': 'Answer'}, 'done': True,
                'provider_private': 'private extra', **state['response_extra']})
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    import http.client
    original = http.client.HTTPConnection
    def transport(host, port, **kwargs):
        assert (host, port) == ('127.0.0.1', 11435)
        return original(host, server.server_port, **kwargs)
    monkeypatch.setattr(http.client, 'HTTPConnection', transport)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield state
    if state['block']:
        state['block'].set()
    server.shutdown()
    server.server_close()
    thread.join()


def test_gateway_enforces_private_provider_and_suppresses_reasoning(tmp_path, gpu_probe, provider):
    with TestClient(create_app(configured(tmp_path))) as client:
        response = client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH)
    assert response.status_code == 200
    assert response.json() == {'model': 'deepseek-r1:7b', 'message': {'role': 'assistant', 'content': 'Answer'}, 'done': True}
    assert 'PRIVATE' not in response.text and 'private extra' not in response.text
    path, sent = provider['requests'][0]
    assert path == '/api/chat' and sent['model'] == 'deepseek-r1:7b'
    assert sent['think'] is True and sent['keep_alive'] == 0 and sent['stream'] is False
    assert provider['requests'][-1] == ('/api/generate', {'model': 'deepseek-r1:7b', 'keep_alive': 0})
    assert provider['resident'] is False


@pytest.mark.parametrize('headers', [{}, {'Authorization': 'Bearer inference-test'}, {'Authorization': 'Bearer management-test'}])
def test_auth_precedes_provider_work_even_for_bad_body(tmp_path, gpu_probe, provider, headers):
    with TestClient(create_app(configured(tmp_path))) as client:
        response = client.post('/assistant/api/chat', content=b'not json private prompt', headers=headers)
    assert response.status_code == 401
    assert provider['requests'] == []


def test_disabled_gateway_does_not_contact_provider(tmp_path, provider):
    with TestClient(create_app(configured(tmp_path, assistant_token=''))) as client:
        response = client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH)
    assert response.status_code == 404 and provider['requests'] == []


@pytest.mark.parametrize('change', [
    {'model': 'other'}, {'model': 'http://attacker/model'}, {'stream': True}, {'keep_alive': '5m'},
    {'options': {'num_ctx': 16385}}, {'options': {'num_predict': 2049}}, {'options': {'num_ctx': True}},
    {'options': {'evil': 1}}, {'messages': [{'role': 'tool', 'content': 'x'}]},
    {'messages': [{'role': 'user', 'content': '界' * 4001}]}, {'messages': []},
    {'messages': [{'role': 'user', 'content': 'x', 'images': ['private']}]}, {'url': 'http://attacker'},
])
def test_invalid_requests_are_bounded_and_never_echo_prompt(tmp_path, provider, change):
    with TestClient(create_app(configured(tmp_path))) as client:
        response = client.post('/assistant/api/chat', json={**PAYLOAD, **change}, headers=AUTH)
    assert response.status_code == 422
    assert response.json() == {'error_code': 'invalid_request'}
    assert provider['requests'] == []


def test_raw_body_limit_before_json_parse(tmp_path, provider):
    with TestClient(create_app(configured(tmp_path))) as client:
        response = client.post('/assistant/api/chat', content=b'x' * 65537, headers=AUTH)
    assert response.status_code == 413 and provider['requests'] == []


def test_provider_error_is_sanitized_and_unloaded(tmp_path, gpu_probe, provider, caplog):
    provider['failure'] = True
    with TestClient(create_app(configured(tmp_path))) as client:
        response = client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH)
    assert response.status_code == 503 and response.json() == {'error_code': 'provider_unavailable'}
    assert provider['resident'] is False
    assert 'private' not in response.text and 'bearer-secret' not in caplog.text


def _attempt_lease(path, queue):
    from app.gpu import GPULease, GPUUnavailable
    try:
        with GPULease(path):
            queue.put('acquired')
    except GPUUnavailable:
        queue.put('busy')


def competing_process(path):
    context = multiprocessing.get_context('spawn')
    queue = context.Queue()
    child = context.Process(target=_attempt_lease, args=(path, queue))
    child.start()
    result = queue.get(timeout=10)
    child.join(10)
    assert child.exitcode == 0
    return result


def test_real_file_lease_excludes_processes_and_releases(tmp_path):
    from app.gpu import GPULease
    path = tmp_path / 'gpu.lock'
    with GPULease(path):
        assert competing_process(path) == 'busy'
    assert competing_process(path) == 'acquired'


def test_lease_held_through_verified_unload(tmp_path, gpu_probe, provider):
    provider['cleanup_lock_check'] = lambda: assert_busy(tmp_path / 'gpu.lock')
    with TestClient(create_app(configured(tmp_path, assistant_cleanup_seconds=3))) as client:
        assert client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH).status_code == 200
    assert competing_process(tmp_path / 'gpu.lock') == 'acquired'


def assert_busy(path):
    assert competing_process(path) == 'busy'


def test_unload_failure_poisons_lease_for_other_processes(tmp_path, gpu_probe, provider):
    provider['unload_failure'] = True
    with TestClient(create_app(configured(tmp_path))) as client:
        response = client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH)
        assert response.status_code == 503
        assert response.json() == {'error_code': 'provider_unavailable'}
        assert client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH).json() == {'error_code': 'generation_busy'}
    assert competing_process(tmp_path / 'gpu.lock') == 'busy'


def test_busy_and_insufficient_real_gpu_admission_do_not_contact_provider(tmp_path, gpu_probe, provider):
    from app.gpu import GPULease
    settings = configured(tmp_path, assistant_gpu_bytes=9 * 1024**3)
    with TestClient(create_app(settings)) as client:
        assert client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH).json() == {'error_code': 'generation_busy'}
        with GPULease(settings.gpu_lease_path):
            assert client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH).status_code == 503
    assert provider['requests'] == []


def test_registry_prediction_obeys_shared_lease(model_tree, tmp_path):
    from app.gpu import GPULease, GPUUnavailable
    root, activation, _, _ = model_tree
    activate(activation)
    registry = Registry(root, activation, gpu_lease_path=tmp_path / 'gpu.lock')
    with GPULease(tmp_path / 'gpu.lock'), pytest.raises(GPUUnavailable):
        registry.predict('ginet-tcd-revisi', '1.0.0', None)


def test_timeout_leaves_durable_exclusion_even_after_late_provider_completion(tmp_path, gpu_probe, provider):
    provider['block'] = threading.Event()
    with TestClient(create_app(configured(tmp_path, assistant_timeout_seconds=.05))) as client:
        response = client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH)
        assert response.status_code == 504
        assert response.json() == {'error_code': 'provider_timeout'}
    provider['block'].set()
    assert competing_process(tmp_path / 'gpu.lock') == 'busy'


def test_disconnect_cannot_release_generation_lease(tmp_path, gpu_probe, provider):
    """Cancel the actual ASGI task while the blocking HTTP generation is active."""
    import httpx
    provider['block'] = threading.Event()
    async def exercise():
        app = create_app(configured(tmp_path, assistant_timeout_seconds=5))
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url='http://test') as client:
            task = asyncio.create_task(client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH))
            assert await asyncio.to_thread(provider['entered'].wait, 3)
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
            assert await asyncio.to_thread(competing_process, tmp_path / 'gpu.lock') == 'busy'
            provider['block'].set()
            # The worker continues through cleanup despite the disconnected ASGI task.
            for _ in range(100):
                if not (tmp_path / 'gpu.lock').read_bytes():
                    break
                await asyncio.sleep(.02)
            assert (tmp_path / 'gpu.lock').read_bytes() == b''
    asyncio.run(exercise())
    assert competing_process(tmp_path / 'gpu.lock') == 'acquired'


def test_compatibility_lease_admission_precedes_gpu_probe(model_tree, tmp_path, gpu_probe):
    from app.compatibility import Compatibility
    from app.gpu import GPULease
    from fastapi import HTTPException
    root, activation, directory, _ = model_tree
    registry = Registry(root, activation, gpu_lease_path=tmp_path / 'gpu.lock')
    with GPULease(tmp_path / 'gpu.lock'), pytest.raises(HTTPException) as raised:
        Compatibility(registry, 1024, 2048)(directory)
    assert raised.value.status_code == 503


@pytest.fixture
def legacy(monkeypatch):
    state = {'requests': []}
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass
        def do_POST(self):
            body = self.rfile.read(int(self.headers['Content-Length']))
            state['requests'].append((self.path, self.headers.get('Authorization'), self.headers.get('Content-Type'), body))
            self.send_response(201)
            self.send_header('Content-Type', 'image/tiff')
            self.send_header('Content-Disposition', 'attachment; filename="prediction.tif"')
            self.end_headers()
            self.wfile.write(b'II\x2a\x00legacy-image')
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    import http.client
    original = http.client.HTTPConnection
    def transport(host, port, **kwargs):
        assert (host, port) == ('127.0.0.1', 8000)
        return original(host, server.server_port, **kwargs)
    monkeypatch.setattr(http.client, 'HTTPConnection', transport)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield state
    server.shutdown()
    server.server_close()
    thread.join()


def test_legacy_proxy_preserves_bearer_multipart_and_image_semantics(tmp_path, legacy):
    settings = configured(tmp_path, legacy_proxy_enabled=True, legacy_inference_token='legacy-test')
    body = b'--test\r\nprivate TIFF bytes\r\n--test--\r\n'
    headers = {'Authorization': 'Bearer legacy-test', 'Content-Type': 'multipart/form-data; boundary=test'}
    with TestClient(create_app(settings)) as client:
        response = client.post('/assistant/legacy/predict/ginet-v1-0-0', content=body, headers=headers)
    assert response.status_code == 201 and response.content == b'II\x2a\x00legacy-image'
    assert response.headers['content-type'] == 'image/tiff'
    assert response.headers['content-disposition'] == 'attachment; filename="prediction.tif"'
    assert legacy['requests'] == [('/predict/ginet-v1-0-0', 'Bearer legacy-test', 'multipart/form-data; boundary=test', body)]
    assert competing_process(settings.gpu_lease_path) == 'acquired'


@pytest.mark.parametrize('suffix', ['http://attacker', '..', 'bad%2fname', 'bad%5cname', 'a..b', 'models', 'name/extra'])
def test_legacy_proxy_rejects_arbitrary_paths(tmp_path, legacy, suffix):
    settings = configured(tmp_path, legacy_proxy_enabled=True, legacy_inference_token='legacy-test')
    # /models is deliberately outside the sole prediction prefix.
    route = '/assistant/legacy/models' if suffix == 'models' else '/assistant/legacy/predict/' + suffix
    with TestClient(create_app(settings)) as client:
        response = client.post(route, content=b'body', headers={'Authorization': 'Bearer legacy-test'})
    assert response.status_code in (404, 422)
    assert legacy['requests'] == []


def test_legacy_proxy_refuses_wrong_auth_and_gpu_overlap(tmp_path, legacy):
    from app.gpu import GPULease
    settings = configured(tmp_path, legacy_proxy_enabled=True, legacy_inference_token='legacy-test')
    with TestClient(create_app(settings)) as client:
        route = '/assistant/legacy/predict/ginet-v1'
        assert client.post(route, headers=AUTH).status_code == 401
        with GPULease(settings.gpu_lease_path):
            response = client.post(route, headers={'Authorization': 'Bearer legacy-test'})
            assert response.status_code == 503
    assert legacy['requests'] == []


def test_explicit_legacy_proxy_preserves_original_unauthenticated_contract(tmp_path, legacy):
    settings = configured(tmp_path, legacy_proxy_enabled=True, legacy_inference_token='')
    with TestClient(create_app(settings)) as client:
        response = client.post('/assistant/legacy/predict/gin-tcd', content=b'image bytes')
    assert response.status_code == 201
    assert legacy['requests'][0][1] is None


def test_legacy_proxy_is_disabled_by_default_even_if_assistant_enabled(tmp_path, legacy):
    with TestClient(create_app(configured(tmp_path))) as client:
        assert client.post('/assistant/legacy/predict/gin-tcd', headers=AUTH).status_code == 404
    assert legacy['requests'] == []


@pytest.mark.parametrize('token', ['inference-test', 'management-test', 'legacy-test', ' bad', 'bad token', 'tökén'])
def test_assistant_requires_distinct_valid_optional_credential(tmp_path, token):
    with pytest.raises(ValueError):
        Settings(tmp_path / 'models', tmp_path / 'active.json', 'inference-test', 'management-test',
                 assistant_token=token, legacy_inference_token='legacy-test')


def test_bounded_threads_reach_fixed_provider(tmp_path, gpu_probe, provider):
    payload = {**PAYLOAD, 'options': {**PAYLOAD['options'], 'num_thread': 4}}
    with TestClient(create_app(configured(tmp_path))) as client:
        response = client.post('/assistant/api/chat', json=payload, headers=AUTH)
    assert response.status_code == 200
    assert provider['requests'][0][1]['options']['num_thread'] == 4


@pytest.mark.parametrize('threads', [0, 17, True, '4'])
def test_unbounded_threads_do_not_reach_provider(tmp_path, provider, threads):
    payload = {**PAYLOAD, 'options': {'num_thread': threads}}
    with TestClient(create_app(configured(tmp_path))) as client:
        assert client.post('/assistant/api/chat', json=payload, headers=AUTH).status_code == 422
    assert provider['requests'] == []


def test_abrupt_provider_disconnect_leaves_durable_gpu_exclusion(tmp_path, gpu_probe, provider):
    # A reset provides no proof generation stopped, even if cleanup sees empty ps.
    provider['disconnect'] = True
    with TestClient(create_app(configured(tmp_path))) as client:
        assert client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH).status_code == 503
    assert provider['resident'] is False
    assert competing_process(tmp_path / 'gpu.lock') == 'busy'


def _crash_with_residency_marker(path):
    import os
    from app.gpu import GPULease
    with GPULease(path) as lease:
        lease.uncertain()
        os._exit(0)


def test_worker_crash_retains_cross_process_residency_exclusion(tmp_path):
    context = multiprocessing.get_context('spawn')
    child = context.Process(target=_crash_with_residency_marker, args=(tmp_path / 'gpu.lock',))
    child.start()
    child.join(10)
    assert child.exitcode == 0
    assert competing_process(tmp_path / 'gpu.lock') == 'busy'


def test_compatibility_child_is_inside_parent_lease_without_reacquiring(model_tree, tmp_path, gpu_probe, monkeypatch):
    """The real spawned child checks flock without any TensorFlow/GPU import."""
    from app.compatibility import Compatibility
    import app.compatibility as compatibility
    root, activation, directory, _ = model_tree
    lock = tmp_path / 'gpu.lock'
    observed = tmp_path / 'child-observed-lock'
    child = tmp_path / 'compatibility-probe'
    child.write_text('''#!/usr/bin/env python3
import fcntl, os
with open(os.environ['GPU_TEST_LOCK'], 'rb') as handle:
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        open(os.environ['GPU_TEST_OBSERVED'], 'w').write('parent owns lease')
        raise SystemExit(0)
raise SystemExit(1)
''')
    child.chmod(0o700)
    monkeypatch.setenv('GPU_TEST_LOCK', str(lock))
    monkeypatch.setenv('GPU_TEST_OBSERVED', str(observed))
    monkeypatch.setattr(compatibility.sys, 'executable', str(child))
    registry = Registry(root, activation, gpu_lease_path=lock)
    Compatibility(registry, 1024, 2048)(directory)
    assert observed.read_text() == 'parent owns lease'
    assert competing_process(lock) == 'acquired'


@pytest.mark.parametrize('reason', ['stop', 'length'])
def test_completion_reason_and_safe_integer_metrics_reach_backend(tmp_path, gpu_probe, provider, reason):
    provider['response_extra'] = {'done_reason': reason, 'total_duration': 700, 'load_duration': 10,
        'prompt_eval_count': 42, 'prompt_eval_duration': 90, 'eval_count': 18, 'eval_duration': 600,
        'unsafe_metric': 'private prompt', 'error': 'private details', 'detail': 'private details'}
    with TestClient(create_app(configured(tmp_path))) as client:
        response = client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH)
    assert response.status_code == 200
    assert response.json() == {'model': 'deepseek-r1:7b', 'message': {'role': 'assistant', 'content': 'Answer'},
        'done': True, 'done_reason': reason, 'total_duration': 700, 'load_duration': 10,
        'prompt_eval_count': 42, 'prompt_eval_duration': 90, 'eval_count': 18, 'eval_duration': 600}


def test_malformed_provider_metrics_and_untrusted_completion_reason_are_omitted(tmp_path, gpu_probe, provider):
    provider['response_extra'] = {'done_reason': 'private prompt', 'total_duration': -1, 'load_duration': True,
        'prompt_eval_count': 1.5, 'prompt_eval_duration': 'private prompt', 'eval_count': 2**80, 'eval_duration': None}
    with TestClient(create_app(configured(tmp_path))) as client:
        response = client.post('/assistant/api/chat', json=PAYLOAD, headers=AUTH)
    assert response.status_code == 200
    assert response.json() == {'model': 'deepseek-r1:7b', 'message': {'role': 'assistant', 'content': 'Answer'}, 'done': True}


def test_killed_compatibility_parent_keeps_live_child_gpu_excluded(model_tree, tmp_path, gpu_probe):
    """An isolated subreaper owns cleanup of the deliberately orphaned CPU child."""
    import subprocess
    import sys
    root, activation, directory, _ = model_tree
    stub = tmp_path / 'compatibility-blocking-child'
    stub.write_text('''#!/usr/bin/env python3
import os, time
from pathlib import Path
state = Path(os.environ['COMPATIBILITY_DEATH_STATE'])
(state / 'child-ready.tmp').write_text(str(os.getpid()))
(state / 'child-ready.tmp').replace(state / 'child-ready')
deadline = time.monotonic() + 30
while not (state / 'release-child').exists() and time.monotonic() < deadline:
    time.sleep(.02)
(state / 'child-exited').write_text('exited')
''')
    stub.chmod(0o700)
    # A separate Linux subreaper makes the orphan a child we can conclusively
    # reap, avoiding detached test processes or changing pytest's process state.
    monitor = '''
import ctypes, os, subprocess, sys, time
from pathlib import Path
assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
root, activation, directory, state, stub = sys.argv[1:]
state = Path(state)
env = dict(os.environ, COMPATIBILITY_DEATH_STATE=str(state))
code = """
import sys
from app.registry import Registry
from app.compatibility import Compatibility
import app.compatibility as compatibility
root, activation, directory, lock, stub = sys.argv[1:]
compatibility.sys.executable = stub
Compatibility(Registry(root, activation, gpu_lease_path=lock), 1024, 2048)(directory)
"""
parent = subprocess.Popen([sys.executable, '-c', code, root, activation, directory,
                           str(state / 'gpu.lock'), stub], env=env)
child_pid = None
try:
    deadline = time.monotonic() + 10
    ready = state / 'child-ready'
    while not ready.exists():
        assert parent.poll() is None, 'compatibility parent exited before child launch'
        assert time.monotonic() < deadline, 'compatibility child did not launch'
        time.sleep(.02)
    child_pid = int(ready.read_text())
    parent.kill()
    parent.wait(timeout=5)
    os.kill(child_pid, 0)
    assert not (state / 'child-exited').exists()
    contender = """
import sys
from app.gpu import GPULease, GPUUnavailable
try:
    with GPULease(sys.argv[1]):
        print('acquired')
except GPUUnavailable:
    print('busy')
"""
    result = subprocess.run([sys.executable, '-c', contender, str(state / 'gpu.lock')],
                            capture_output=True, text=True, check=True, timeout=5)
    print(result.stdout.strip())
finally:
    if parent.poll() is None:
        parent.kill()
        parent.wait(timeout=5)
    (state / 'release-child').touch()
    if child_pid is not None:
        os.waitpid(child_pid, 0)
'''
    result = subprocess.run([sys.executable, '-c', monitor, str(root), str(activation), str(directory),
                             str(tmp_path), str(stub)], capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / 'child-exited').read_text() == 'exited'
    assert result.stdout.strip() == 'busy'


@pytest.mark.parametrize('outcome', ['failed', 'timeout', 'dispatch_error', 'unknown_exit'])
def test_compatibility_clears_residency_only_after_confirmed_child_exit(model_tree, tmp_path, gpu_probe, monkeypatch, outcome):
    import subprocess
    import app.compatibility as compatibility
    from app.compatibility import Compatibility
    from fastapi import HTTPException
    root, activation, directory, _ = model_tree
    lock = tmp_path / 'gpu.lock'
    original = compatibility.subprocess.run
    def child_boundary(command, **kwargs):
        if command[0] == 'nvidia-smi':
            return original(command, **kwargs)
        kwargs.pop('env', None)  # Never render inherited environment in assertion diagnostics.
        # Before any dispatch, a separate process must still be excluded after
        # parent death; the durable marker is observable before this boundary.
        assert lock.read_bytes() == b'unverified residency\n'
        if outcome == 'timeout':
            raise subprocess.TimeoutExpired(command, 60)
        if outcome == 'dispatch_error':
            raise OSError('unknown child state')
        return subprocess.CompletedProcess(command, None if outcome == 'unknown_exit' else 1)
    monkeypatch.setattr(compatibility.subprocess, 'run', child_boundary)
    with pytest.raises(HTTPException) as failure:
        Compatibility(Registry(root, activation, gpu_lease_path=lock), 1024, 2048)(directory)
    assert failure.value.status_code == 503
    assert lock.read_bytes() == (b'' if outcome == 'failed' else b'unverified residency\n')
