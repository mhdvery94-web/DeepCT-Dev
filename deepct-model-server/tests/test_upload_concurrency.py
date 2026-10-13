"""Real session transactions and ASGI dispatch under deliberately held locks/I/O."""
import asyncio
from concurrent.futures import ThreadPoolExecutor
from threading import Event, Thread, Timer

import httpx
import pytest
from fastapi import BackgroundTasks

from app import uploads as upload_module
from test_uploads import MGMT, action, begin, put, upload_client


@pytest.mark.parametrize('operation, expected_state', [
    ('activate', 'active'), ('publish', 'ready_for_activate'),
])
def test_status_overlapping_commit_keeps_state_and_operation_metadata(
        upload_client, monkeypatch, operation, expected_state):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    assert put(client, session, data).status_code == 200
    assert action(client, session, 'finalize').json()['state'] == 'ready_for_test'
    app.state.uploads.compatibility = lambda directory: None
    assert action(client, session, 'test').json()['state'] == 'ready_for_activate'
    if operation == 'activate':
        assert action(client, session, 'publish').json()['published'] is True

    commit_waiting, release_commit = Event(), Event()
    poll_started, poll_replaced = Event(), Event()
    original_replace = upload_module.os.replace
    original_read = app.state.uploads.read
    session_path = app.state.uploads.path(session['id']) / 'session.json'

    def pause_commit(source, target):
        if target == session_path:
            # Ignore scheduling's operation marker; pause the post-mutation save.
            payload = upload_module.read_json(source)
            if payload['published'] and payload['state'] == expected_state:
                if not commit_waiting.is_set():
                    commit_waiting.set()
                    assert release_commit.wait(5), 'test did not release commit'
                else:
                    original_replace(source, target)
                    poll_replaced.set()
                    return
        original_replace(source, target)

    def observe_poll(identifier):
        if commit_waiting.is_set() and not release_commit.is_set():
            poll_started.set()
        return original_read(identifier)

    monkeypatch.setattr(upload_module.os, 'replace', pause_commit)
    monkeypatch.setattr(app.state.uploads, 'read', observe_poll)
    with ThreadPoolExecutor(max_workers=2) as pool:
        control = pool.submit(client.post,
                              f"/management/uploads/{session['id']}/{operation}", headers=MGMT)
        try:
            assert commit_waiting.wait(5), 'control did not reach session commit'
            status = pool.submit(client.get, f"/management/uploads/{session['id']}", headers=MGMT)
            assert poll_started.wait(5), 'status did not enter reconciliation'
            # Broken code replaces the outstanding writer's real temporary file.
            # Correct code waits until the whole transaction has committed.
            poll_replaced.wait(0.2)
        finally:
            release_commit.set()
        assert control.result(timeout=5).status_code == (202 if operation == 'publish' else 200)
        response = status.result(timeout=5)
    assert response.status_code == 200
    assert response.json()['state'] == expected_state
    final = client.get(f"/management/uploads/{session['id']}", headers=MGMT).json()
    assert final['state'] == expected_state
    assert final['published'] is True
    assert 'operation' not in final
    assert 'last_error' not in final


def test_poll_cannot_restore_operation_from_snapshot_before_cleanup(upload_client, monkeypatch):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    assert put(client, session, data).status_code == 200
    assert action(client, session, 'finalize').json()['state'] == 'ready_for_test'
    app.state.uploads.compatibility = lambda directory: None
    assert action(client, session, 'test').json()['state'] == 'ready_for_activate'
    uploads = app.state.uploads
    committed, allow_cleanup = Event(), Event()
    snapshot_read, allow_poll_save, cleanup_done = Event(), Event(), Event()
    original_action, original_read_json = uploads.action, upload_module.read_json
    session_path = uploads.path(session['id']) / 'session.json'

    def pause_before_cleanup(*args, **kwargs):
        result = original_action(*args, **kwargs)
        committed.set()
        assert allow_cleanup.wait(5)
        return result

    def pause_old_snapshot(path):
        result = original_read_json(path)
        if path == session_path and committed.is_set() and not snapshot_read.is_set():
            assert result['operation'] == 'publish'
            snapshot_read.set()
            assert allow_poll_save.wait(5)
        return result

    monkeypatch.setattr(uploads, 'action', pause_before_cleanup)
    monkeypatch.setattr(upload_module, 'read_json', pause_old_snapshot)
    with ThreadPoolExecutor(max_workers=2) as pool:
        control = pool.submit(client.post, f"/management/uploads/{session['id']}/publish", headers=MGMT)
        control.add_done_callback(lambda _: cleanup_done.set())
        try:
            assert committed.wait(5)
            status = pool.submit(client.get, f"/management/uploads/{session['id']}", headers=MGMT)
            assert snapshot_read.wait(5)
            allow_cleanup.set()
            # Without a transaction lock cleanup finishes now; the old poll
            # then writes its snapshot and resurrects operation=publish.
            cleanup_done.wait(0.2)
        finally:
            allow_cleanup.set()
            allow_poll_save.set()
        assert control.result(timeout=5).status_code == 202
        assert status.result(timeout=5).status_code == 200
    final = client.get(f"/management/uploads/{session['id']}", headers=MGMT).json()
    assert final['published'] is True
    assert final['state'] == 'ready_for_activate'
    assert 'operation' not in final
    assert 'last_error' not in final


def test_running_compatibility_can_be_polled_while_registry_is_locked(upload_client):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    assert put(client, session, data).status_code == 200
    assert action(client, session, 'finalize').json()['state'] == 'ready_for_test'
    running, release = Event(), Event()

    def compatibility(directory):
        running.set()
        assert release.wait(5), 'test did not release compatibility boundary'

    app.state.uploads.compatibility = compatibility
    with ThreadPoolExecutor(max_workers=2) as pool:
        control = pool.submit(client.post, f"/management/uploads/{session['id']}/test", headers=MGMT)
        try:
            assert running.wait(5)
            assert not app.state.registry.lock.acquire(blocking=False)
            status = pool.submit(client.get, f"/management/uploads/{session['id']}", headers=MGMT)
            response = status.result(timeout=1)
            assert response.status_code == 200
            assert response.json()['operation'] == 'test'
            assert response.json()['compatibility'] == 'untested'
            assert response.json()['state'] == 'ready_for_test'
            conflict = client.post(f"/management/uploads/{session['id']}/cancel", headers=MGMT)
            assert conflict.status_code == 409
        finally:
            release.set()
        assert control.result(timeout=5).status_code == 202
    final = client.get(f"/management/uploads/{session['id']}", headers=MGMT).json()
    assert final['state'] == 'ready_for_activate'
    assert 'operation' not in final


def test_action_waiting_for_registry_rechecks_newly_reserved_operation(upload_client, monkeypatch):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    assert put(client, session, data).status_code == 200
    assert action(client, session, 'finalize').json()['state'] == 'ready_for_test'
    uploads = app.state.uploads
    uploads.compatibility = lambda directory: None
    entered_action = Event()
    original_action = uploads.action

    def observe_action(*args, **kwargs):
        entered_action.set()
        return original_action(*args, **kwargs)

    monkeypatch.setattr(uploads, 'action', observe_action)
    background = BackgroundTasks()
    with ThreadPoolExecutor(max_workers=2) as pool:
        app.state.registry.lock.acquire()
        try:
            cancel = pool.submit(client.post, f"/management/uploads/{session['id']}/cancel", headers=MGMT)
            assert entered_action.wait(5)
            reserve = pool.submit(uploads.schedule, session['id'], 'test', background)
            result, status = reserve.result(timeout=1)
            assert status == 202
            assert result['operation'] == 'test'
        finally:
            app.state.registry.lock.release()
        assert cancel.result(timeout=5).status_code == 409
    asyncio.run(background())
    final = client.get(f"/management/uploads/{session['id']}", headers=MGMT).json()
    assert final['state'] == 'ready_for_activate'
    assert 'operation' not in final


@pytest.mark.parametrize('blocked_at', ['authorization_lock', 'commit_lock', 'chunk_fsync'])
def test_put_leaves_heartbeat_and_health_responsive(upload_client, monkeypatch, blocked_at):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)
    blocked, release, watchdog_fired = Event(), Event(), Event()

    def watchdog():
        watchdog_fired.set()
        release.set()

    def hold_registry():
        with app.state.registry.lock:
            blocked.set()
            assert release.wait(5), 'test did not release registry lock'

    holder = Thread(target=hold_registry)
    original_fsync = upload_module.os.fsync

    def held_fsync(descriptor):
        blocked.set()
        assert release.wait(5), 'test did not release fsync'
        return original_fsync(descriptor)

    if blocked_at == 'authorization_lock':
        holder.start()
        assert blocked.wait(5)
    elif blocked_at == 'chunk_fsync':
        monkeypatch.setattr(upload_module.os, 'fsync', held_fsync)

    async def exercise():
        async def body():
            if blocked_at == 'commit_lock':
                holder.start()
                assert await asyncio.to_thread(blocked.wait, 5)
            yield data

        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),
                                    base_url='http://testserver') as async_client:
            request = asyncio.create_task(async_client.put(
                f"/uploads/{session['id']}", content=body(), headers={
                    'Authorization': 'Bearer ' + session['token'], 'Upload-Offset': '0',
                }))
            try:
                assert await asyncio.to_thread(blocked.wait, 5)
                await asyncio.sleep(0.01)  # Independent event-loop heartbeat.
                health = await async_client.get('/')
                responsive_while_blocked = not release.is_set()
            finally:
                release.set()
            response = await request
        assert health.status_code == 200
        assert health.json()['status'] == 'running'
        assert responsive_while_blocked and not watchdog_fired.is_set()
        assert response.status_code == 200
        assert response.json()['offset'] == len(data)

    timer = Timer(2, watchdog)
    timer.start()
    try:
        asyncio.run(exercise())
    finally:
        release.set()
        timer.cancel()
        if holder.ident is not None:
            holder.join(timeout=5)


@pytest.mark.parametrize('during_body, expected_status, expected_offset', [
    ('renew', 401, 0), ('expire', 401, 0), ('cancel', 409, 0), ('advance', 409, 1),
])
def test_put_rechecks_capability_state_and_offset_after_body(
        upload_client, during_body, expected_status, expected_offset):
    client, app, manifest, data = upload_client
    session = begin(client, manifest)

    async def exercise():
        async def body():
            if during_body == 'expire':
                app.state.uploads.clock = lambda: session['expires_at']
            elif during_body == 'advance':
                await asyncio.to_thread(app.state.uploads.chunk, session['id'], session['token'], 0, data[:1])
            else:
                await asyncio.to_thread(app.state.uploads.action, session['id'], during_body)
            yield data

        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),
                                    base_url='http://testserver') as async_client:
            response = await async_client.put(f"/uploads/{session['id']}", content=body(), headers={
                'Authorization': 'Bearer ' + session['token'], 'Upload-Offset': '0',
            })
        assert response.status_code == expected_status

    asyncio.run(exercise())
    assert app.state.uploads.read(session['id'])['offset'] == expected_offset


def test_invalid_capability_is_rejected_before_stream_is_consumed(upload_client):
    client, app, manifest, _ = upload_client
    session = begin(client, manifest)

    async def exercise():
        async def body():
            pytest.fail('Unauthorized request body must not be consumed')
            yield b'unreachable'

        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),
                                    base_url='http://testserver') as async_client:
            response = await async_client.put(f"/uploads/{session['id']}", content=body(), headers={
                'Authorization': 'Bearer wrong', 'Upload-Offset': '0',
            })
        assert response.status_code == 401

    asyncio.run(exercise())
