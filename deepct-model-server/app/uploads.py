"""Durable, bounded upload sessions. Deployment uses exactly one worker process."""
import ctypes
import hashlib
import json
import os
import secrets
import shutil
import time
import uuid
from threading import RLock

from fastapi import HTTPException

from .registry import Manifest, RegistryError, read_json

CHUNK_BYTES = 4 * 1024**2
HEADROOM = 2 * 1024**3
TOKEN_SECONDS = 15 * 60
TERMINAL = {'cancelled', 'failed', 'active'}


def atomic_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    with temporary.open('w') as handle:
        json.dump(payload, handle)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)
    fsync_directory(path.parent)


def fsync_directory(path):
    descriptor = os.open(path, os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def publish_no_replace(source, target):
    # Linux deployment: renameat2 is an atomic no-replace directory transaction.
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.renameat2(-100, os.fsencode(source), -100, os.fsencode(target), 1):
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))
    fsync_directory(target.parent)
    fsync_directory(source.parent)


class Uploads:
    def __init__(self, registry, compatibility=None):
        self.registry = registry
        self.root = registry.root.parent / '.incoming'
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.clock = time.time
        self.free_bytes = lambda: shutil.disk_usage(self.root).free
        self.compatibility = compatibility or self.unavailable
        self.control_lock = RLock()
        # No background work survives restart; reconcile committed byte offsets
        # and return interrupted validation/testing to a retryable state.
        for path in self.root.iterdir():
            if not path.is_dir() or not (path / 'session.json').exists():
                continue
            session = self.read(path.name)
            weights = path / 'candidate' / session['manifest']['weight_file']
            if weights.exists() and weights.stat().st_size > session['offset']:
                with weights.open('r+b') as handle:
                    handle.truncate(session['offset'])
                    handle.flush()
                    os.fsync(handle.fileno())
            operation = session.pop('operation', None)
            if session['state'] == 'validating':
                session['state'] = 'uploaded'
            if operation:
                session['last_error'] = 'interrupted_retry_required'
            self.save(session)

    @staticmethod
    def unavailable(directory):
        raise HTTPException(503, 'GPU compatibility test unavailable; model remains inactive')

    def path(self, identifier):
        try:
            if str(uuid.UUID(identifier)) != identifier:
                raise ValueError()
        except ValueError:
            raise HTTPException(404, 'Upload not found') from None
        return self.root / identifier

    def read(self, identifier):
        path = self.path(identifier)
        if not (path / 'session.json').exists():
            raise HTTPException(404, 'Upload not found')
        session = read_json(path / 'session.json')
        candidate = path / 'candidate'
        # Reconcile a crash after atomic publish but before metadata save.
        target = self.registry.root / session['manifest']['model_id'] / session['manifest']['version']
        if not candidate.exists() and target.exists() and session['state'] == 'ready_for_activate':
            if self.registry._manifest(target).model_dump() == session['manifest']:
                session['published'] = True
                self.save(session)
        if session['published']:
            key = (session['manifest']['model_id'], session['manifest']['version'])
            state = 'active' if key in self.registry.active_versions() else 'ready_for_activate'
            if session['state'] != state:
                session['state'] = state
                self.save(session)
        return session

    def save(self, session):
        atomic_json(self.path(session['id']) / 'session.json', session)

    @staticmethod
    def public(session):
        return {key: value for key, value in session.items() if key != 'token_hash'}

    def sessions(self):
        return [self.read(path.name) for path in self.root.iterdir()
                if path.is_dir() and (path / 'session.json').exists()]

    def disk_guard(self, additional=0):
        remaining = sum(s['manifest']['size_bytes'] - s['offset'] for s in self.sessions()
                        if s['state'] not in TERMINAL and not s['published'])
        if self.free_bytes() < HEADROOM + remaining + additional:
            raise HTTPException(507, 'Insufficient disk headroom')

    def renew(self, session):
        if session['state'] not in {'uploading', 'uploaded'}:
            raise HTTPException(409, 'Upload no longer accepts bytes')
        token = secrets.token_urlsafe(32)
        session['token_hash'] = hashlib.sha256(token.encode()).hexdigest()
        session['expires_at'] = int(self.clock()) + TOKEN_SECONDS
        self.save(session)
        return self.public(session) | {'token': token}

    def create(self, manifest):
        with self.registry.lock:
            try:
                self.registry.assert_version_available(*manifest.key)
            except RegistryError:
                raise HTTPException(409, 'Immutable version already exists') from None
            for other in self.sessions():
                if other['state'] not in {'cancelled', 'failed'} and (other['manifest']['model_id'], other['manifest']['version']) == manifest.key:
                    raise HTTPException(409, 'Version already reserved')
            self.disk_guard(manifest.size_bytes)
            identifier = str(uuid.uuid4())
            directory = self.path(identifier) / 'candidate'
            directory.mkdir(parents=True, mode=0o700)
            atomic_json(directory / 'manifest.json', manifest.model_dump())
            (directory / manifest.weight_file).touch(mode=0o600)
            session = {'id': identifier, 'manifest': manifest.model_dump(), 'offset': 0,
                       'state': 'uploading', 'published': False, 'compatibility': 'untested'}
            result = self.renew(session)
            # Persist the newly created session directory entry as well as its
            # files before acknowledging a durable resumable session.
            fsync_directory(self.root)
            return result

    def authorize(self, session, token):
        digest = hashlib.sha256(token.encode()).hexdigest()
        if self.clock() >= session['expires_at'] or not secrets.compare_digest(digest, session['token_hash']):
            raise HTTPException(401, 'Invalid or expired upload capability')

    def chunk(self, identifier, token, offset, data):
        with self.registry.lock:
            session = self.read(identifier)
            self.authorize(session, token)
            if session['state'] != 'uploading' or offset != session['offset']:
                raise HTTPException(409, 'Reconcile the upload offset before retrying')
            if not data or len(data) > CHUNK_BYTES or offset + len(data) > session['manifest']['size_bytes']:
                raise HTTPException(413, 'Invalid chunk size')
            self.disk_guard()
            path = self.path(identifier) / 'candidate' / session['manifest']['weight_file']
            with path.open('r+b') as handle:
                handle.seek(offset)
                handle.write(data)
                handle.flush()
                os.fsync(handle.fileno())
            session['offset'] += len(data)
            if session['offset'] == session['manifest']['size_bytes']:
                session['state'] = 'uploaded'
            self.save(session)
            return self.public(session)

    def schedule(self, identifier, action, background):
        with self.control_lock:
            session = self.read(identifier)
            if session.get('operation'):
                raise HTTPException(409, 'An operation is already running; poll status')
            if action not in {'finalize', 'test', 'publish'}:
                return self.action(identifier, action), 200
            expected = {'finalize': 'uploaded', 'test': 'ready_for_test', 'publish': 'ready_for_activate'}
            if session['state'] != expected[action]:
                raise HTTPException(409, 'Session is not ready for this operation')
            session['operation'] = action
            session.pop('last_error', None)
            self.save(session)
            background.add_task(self.complete, identifier, action)
            return self.public(session), 202

    def complete(self, identifier, action):
        error = None
        try:
            self.action(identifier, action)
        except HTTPException as exc:
            error = 'unavailable' if exc.status_code in {503, 507} else 'validation_failed'
        except (RegistryError, OSError):
            error = 'validation_failed'
        finally:
            with self.control_lock:
                session = self.read(identifier)
                session.pop('operation', None)
                if session['state'] == 'validating':
                    session['state'] = 'uploaded'
                if error:
                    session['last_error'] = error
                self.save(session)

    def action(self, identifier, action):
        with self.registry.lock:
            session = self.read(identifier)
            directory = self.path(identifier) / 'candidate'
            manifest = Manifest.model_validate(session['manifest'])
            if action == 'renew':
                return self.renew(session)
            if action == 'cancel':
                if session['published']:
                    raise HTTPException(409, 'Published versions are immutable')
                session['state'] = 'cancelled'
                self.save(session)
                # Only this incoming session; never remove published weights.
                shutil.rmtree(directory, ignore_errors=True)
            elif action == 'finalize':
                if session['state'] != 'uploaded':
                    raise HTTPException(409, 'Upload must be complete')
                session['state'] = 'validating'
                self.save(session)
                try:
                    self.disk_guard(manifest.size_bytes)  # private verification copy
                    self.registry.validate_candidate(directory)
                except (RegistryError, OSError):
                    session['state'] = 'failed'
                    self.save(session)
                    raise HTTPException(422, 'Model integrity or format validation failed') from None
                session['state'] = 'ready_for_test'
            elif action == 'test':
                if session['state'] != 'ready_for_test':
                    raise HTTPException(409, 'Model is not ready for compatibility testing')
                self.disk_guard(manifest.size_bytes)
                self.compatibility(directory)
                session['compatibility'] = 'structural_shape_passed_not_scientific_validation'
                session['state'] = 'ready_for_activate'
            elif action == 'publish':
                if session['state'] != 'ready_for_activate':
                    raise HTTPException(409, 'A successful compatibility test is required')
                if not session['published']:
                    self.disk_guard(manifest.size_bytes)
                    self.registry.validate_candidate(directory)
                    target = self.registry.assert_version_available(*manifest.key)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    fsync_directory(self.registry.root)
                    try:
                        publish_no_replace(directory, target)
                    except FileExistsError:
                        raise HTTPException(409, 'Immutable version already exists') from None
                    session['published'] = True
            elif action in {'activate', 'deactivate'}:
                if not session['published'] or session['state'] not in {'ready_for_activate', 'active'}:
                    raise HTTPException(409, 'Publish tested model before activation')
                active = self.registry.active_versions()
                if action == 'activate':
                    active.add(manifest.key)
                    session['state'] = 'active'
                else:
                    active.discard(manifest.key)
                    session['state'] = 'ready_for_activate'
                atomic_json(self.registry.activation_file, {'active': [dict(model_id=m, version=v) for m, v in sorted(active)]})
            else:
                raise HTTPException(404, 'Unknown upload action')
            self.save(session)
            return self.public(session)
