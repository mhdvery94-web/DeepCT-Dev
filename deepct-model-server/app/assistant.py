"""Private fixed-target Ollama boundary. No provider errors or reasoning escape."""
import http.client
import json
import socket
import re
import time

from fastapi import Depends, Request
from fastapi.responses import JSONResponse, Response
from starlette.concurrency import run_in_threadpool

from .compatibility import gpu_free_bytes
from .gpu import GPULease, GPUUnavailable

MODEL = 'deepseek-r1:7b'
MAX_BODY = 65536


class ProviderUnavailable(RuntimeError):
    pass


class ProviderTimeout(ProviderUnavailable):
    pass


def provider_request(method, path, body=None, timeout=10):
    # http.client ignores proxy environment; host and port are never request data.
    connection = http.client.HTTPConnection('127.0.0.1', 11435, timeout=timeout)
    try:
        encoded = json.dumps(body).encode() if body is not None else None
        connection.request(method, path, encoded, {'Content-Type': 'application/json'})
        response = connection.getresponse()
        raw = response.read(256 * 1024 + 1)
        if response.status != 200 or len(raw) > 256 * 1024:
            raise ProviderUnavailable()
        return json.loads(raw)
    except (socket.timeout, TimeoutError):
        raise ProviderTimeout() from None
    except (OSError, ValueError, http.client.HTTPException):
        raise ProviderUnavailable() from None
    finally:
        connection.close()


def bounded_payload(data):
    if not isinstance(data, dict) or set(data) - {'model', 'messages', 'stream', 'keep_alive', 'options', 'think'}:
        raise ValueError()
    if data.get('model') != MODEL or data.get('stream', False) is not False or type(data.get('keep_alive', 0)) is not int or data.get('keep_alive', 0) != 0:
        raise ValueError()
    messages = data.get('messages')
    if not isinstance(messages, list) or not 1 <= len(messages) <= 128:
        raise ValueError()
    size = 0
    for message in messages:
        if (not isinstance(message, dict) or set(message) != {'role', 'content'}
                or message['role'] not in ('system', 'user', 'assistant') or not isinstance(message['content'], str)):
            raise ValueError()
        size += len(message['content'].encode('utf-8'))
    if size > 12000:
        raise ValueError()
    options = data.get('options', {})
    if not isinstance(options, dict) or set(options) - {'num_ctx', 'num_predict', 'num_thread', 'temperature', 'seed'}:
        raise ValueError()
    for key, maximum in [('num_ctx', 16384), ('num_predict', 2048)]:
        value = options.get(key, maximum)
        if type(value) is not int or not 1 <= value <= maximum:
            raise ValueError()
    if 'num_thread' in options and (type(options['num_thread']) is not int or not 1 <= options['num_thread'] <= 16):
        raise ValueError()
    if 'temperature' in options and (type(options['temperature']) not in (float, int) or not 0 <= options['temperature'] <= 2):
        raise ValueError()
    if 'seed' in options and (type(options['seed']) is not int or not 0 <= options['seed'] <= 2**31 - 1):
        raise ValueError()
    return {'model': MODEL, 'messages': messages, 'stream': False, 'think': True, 'keep_alive': 0,
            'options': {'num_ctx': 16384, 'num_predict': 2048, **options}}


def unload(settings):
    deadline = time.monotonic() + settings.assistant_cleanup_seconds
    provider_request('POST', '/api/generate', {'model': MODEL, 'keep_alive': 0}, timeout=settings.assistant_cleanup_seconds)
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ProviderUnavailable()
        data = provider_request('GET', '/api/ps', timeout=remaining)
        if not isinstance(data, dict) or not isinstance(data.get('models'), list):
            raise ProviderUnavailable()
        if not data['models']:
            return
        time.sleep(min(.05, max(0, deadline - time.monotonic())))


def generate(settings, body):
    try:
        with GPULease(settings.gpu_lease_path) as lease:
            if settings.gpu_lease_path is None or type(settings.assistant_gpu_bytes) is not int or settings.assistant_gpu_bytes <= 0:
                return error(503, 'provider_unavailable')
            if gpu_free_bytes() < settings.assistant_gpu_bytes:
                return error(503, 'generation_busy')
            # Persist before dispatch. A killed worker or ambiguous provider timeout
            # leaves every participant fail-closed across process restarts.
            lease.uncertain()
            timed_out = False
            failed = False
            result = None
            try:
                data = provider_request('POST', '/api/chat', body, timeout=settings.assistant_timeout_seconds)
                message = data.get('message') if isinstance(data, dict) else None
                if (not isinstance(message, dict) or not isinstance(message.get('content'), str)
                        or data.get('done') is not True):
                    raise ProviderUnavailable()
                result = {'model': MODEL, 'message': {'role': 'assistant', 'content': message['content']}, 'done': True}
                if data.get('done_reason') in ('stop', 'length'):
                    result['done_reason'] = data['done_reason']
                for key in ('prompt_eval_count', 'eval_count', 'total_duration', 'load_duration',
                            'prompt_eval_duration', 'eval_duration'):
                    if type(data.get(key)) is int and 0 <= data[key] <= 2**63 - 1:
                        result[key] = data[key]
            except ProviderTimeout:
                timed_out = True
            except ProviderUnavailable:
                failed = True
            finally:
                try:
                    unload(settings)
                    # An unsuccessful generation may still be loading/running after
                    # an empty ps result. An operator must verify the owned unit idle.
                    if not timed_out and not failed:
                        lease.verified_idle()
                except ProviderUnavailable:
                    failed = True
            if timed_out:
                return error(504, 'provider_timeout')
            if failed:
                return error(503, 'provider_unavailable')
            return result
    except GPUUnavailable:
        return error(503, 'generation_busy')
    except Exception:
        # Fixed envelope only; never stringify/log provider exceptions or bodies.
        return error(503, 'provider_unavailable')


def error(status, code):
    return JSONResponse(status_code=status, content={'error_code': code})


def install_assistant_routes(app, settings, bearer_dependency):
    install_legacy_route(app, settings, bearer_dependency)
    if not settings.assistant_token:
        return
    auth = bearer_dependency(settings.assistant_token)

    @app.post('/assistant/api/chat', dependencies=[Depends(auth)])
    async def chat(request: Request):
        raw = bytearray()
        async for chunk in request.stream():
            if len(raw) + len(chunk) > MAX_BODY:
                return error(413, 'invalid_request')
            raw.extend(chunk)
        try:
            body = bounded_payload(json.loads(raw))
        except (ValueError, TypeError, UnicodeError, RecursionError):
            return error(422, 'invalid_request')
        # The synchronous worker owns the lease and cleanup. ASGI cancellation
        # cannot terminate its thread or release the lease during generation.
        return await run_in_threadpool(generate, settings, body)


def legacy_predict(settings, model_name, body, content_type, authorization):
    try:
        with GPULease(settings.gpu_lease_path) as lease:
            if settings.gpu_lease_path is None:
                return error(503, 'provider_unavailable')
            connection = http.client.HTTPConnection('127.0.0.1', 8000, timeout=settings.assistant_timeout_seconds)
            # Unknown completion on connection loss must block future GPU work,
            # including LLM generation, until an operator verifies legacy idle.
            lease.uncertain()
            try:
                connection.request('POST', '/predict/' + model_name, body,
                    ({'Authorization': authorization} if authorization else {}) | {'Content-Type': content_type})
                upstream = connection.getresponse()
                raw = upstream.read(64 * 1024**2 + 1)
                if len(raw) > 64 * 1024**2:
                    raise ProviderUnavailable()
                headers = {key: value for key, value in upstream.getheaders()
                           if key.lower() in ('content-type', 'content-disposition', 'cache-control')}
                lease.verified_idle()
                return Response(raw, status_code=upstream.status, headers=headers)
            finally:
                connection.close()
    except GPUUnavailable:
        return error(503, 'generation_busy')
    except (socket.timeout, TimeoutError):
        return error(504, 'provider_timeout')
    except Exception:
        return error(503, 'provider_unavailable')


def install_legacy_route(app, settings, bearer_dependency):
    if not settings.legacy_proxy_enabled:
        return
    dependencies = [Depends(bearer_dependency(settings.legacy_inference_token))] if settings.legacy_inference_token else []

    @app.post('/assistant/legacy/predict/{model_name}', dependencies=dependencies)
    async def legacy(model_name: str, request: Request):
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,159}', model_name) or '..' in model_name:
            return error(422, 'invalid_request')
        raw = bytearray()
        async for chunk in request.stream():
            if len(raw) + len(chunk) > 64 * 1024**2:
                return error(413, 'invalid_request')
            raw.extend(chunk)
        return await run_in_threadpool(legacy_predict, settings, model_name, bytes(raw),
            request.headers.get('content-type', 'application/octet-stream'), request.headers.get('authorization', ''))
