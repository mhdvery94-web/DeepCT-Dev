"""Immutable version metadata, external activation and verified load snapshots."""
import hashlib
import json
import os
import re
import tempfile
from contextlib import contextmanager
from pathlib import Path
from threading import RLock
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator


class RegistryError(ValueError):
    pass


MODEL_ID = r'[a-z0-9]+(?:-[a-z0-9]+)*'
VERSION = r'(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)'
MAX_WEIGHTS = 10 * 1024**3


class StrictModel(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True, frozen=True)

    @field_validator('schema_version', 'width', 'height', mode='before', check_fields=False)
    @classmethod
    def integer_literal(cls, value):
        # Pydantic Literal equality otherwise accepts True == 1 and 1024.0 == 1024.
        if type(value) is not int:
            raise ValueError('Expected an integer')
        return value


class InputSpec(StrictModel):
    width: Literal[1024]
    height: Literal[1024]
    dtype: Literal['uint16']
    time_scalar: Literal[0.5]


class Manifest(StrictModel):
    schema_version: Literal[1]
    model_id: str = Field(pattern=f'^{MODEL_ID}$', max_length=80)
    version: str = Field(pattern=f'^{VERSION}$', max_length=40)
    name: str = Field(min_length=1, max_length=160)
    description: str = Field(max_length=4000)
    framework: Literal['tensorflow']
    adapter: Literal['ginet-tcd-v1']
    weight_file: Literal['model.h5', 'model.keras']
    sha256: str = Field(pattern=r'^[0-9a-f]{64}$')
    size_bytes: int = Field(gt=0, le=MAX_WEIGHTS)
    input: InputSpec

    @property
    def key(self):
        return self.model_id, self.version


def read_json(path, limit=65536):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > limit:
        raise RegistryError('Invalid metadata file')
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise RegistryError('Duplicate JSON key')
            result[key] = value
        return result
    try:
        with path.open('rb') as handle:
            data = handle.read(limit + 1)
        if len(data) > limit:
            raise RegistryError('Metadata too large')
        return json.loads(data, object_pairs_hook=unique)
    except (OSError, ValueError, RecursionError) as exc:
        raise RegistryError('Invalid metadata') from exc


def fingerprint(path):
    stat = path.stat()
    return stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns


class Registry:
    def predict(self, model_id, version, inputs):
        self._check_identity(model_id, version)
        key = model_id, version
        # Covers activation check, verified loading, GPU switch and inference.
        with self.lock:
            if key not in self.active_versions():
                raise RegistryError('Model version is not activated')
            entry = self.entries().get(key)
            if entry is None:
                raise RegistryError('Model version is unavailable')
            manifest, directory = entry
            signature = (manifest, fingerprint(directory / 'manifest.json'), fingerprint(directory / manifest.weight_file))
            if self._loaded_signature != signature:
                if self._loaded is not None:
                    self._loaded = None
                    self._loaded_signature = None
                    self.loader.release()
                if self.loader is None:
                    from .loaders.tensorflow import TensorFlowLoader
                    self.loader = TensorFlowLoader()
                with self.verified_snapshot(directory) as (_, snapshot):
                    self._loaded = self.loader.load(snapshot)
                self._loaded_signature = signature
            return self._loaded.predict(inputs, verbose=0)

    def __init__(self, root, activation_file, loader=None):
        self.root = Path(root).absolute()
        self.activation_file = Path(activation_file).absolute()
        if self.activation_file.resolve().is_relative_to(self.root.resolve()):
            raise RegistryError('Activation must be outside immutable registry')
        self.loader = loader
        self.lock = RLock()
        self._loaded = None
        self._loaded_signature = None

    def _safe(self, path):
        if not path.is_relative_to(self.root):
            raise RegistryError('Path outside registry')
        for part in (path, *path.parents):
            if part.is_symlink():
                raise RegistryError('Registry symlinks are forbidden')

    def _manifest(self, directory):
        try:
            manifest = Manifest.model_validate(read_json(directory / 'manifest.json'))
            if {item.name for item in directory.iterdir()} != {'manifest.json', manifest.weight_file}:
                raise RegistryError('Unexpected version contents')
            weights = directory / manifest.weight_file
            if weights.is_symlink() or not weights.is_file():
                raise RegistryError('Invalid weight file')
            if weights.stat().st_size != manifest.size_bytes:
                raise RegistryError('Weight size mismatch')
            return manifest
        except (OSError, ValidationError) as exc:
            raise RegistryError('Invalid model version') from exc

    def entries(self):
        result = {}
        self._safe(self.root)
        if not self.root.exists():
            return result
        for model_dir in sorted(self.root.iterdir()):
            self._safe(model_dir)
            if not model_dir.is_dir():
                raise RegistryError('Invalid model directory')
            for directory in sorted(model_dir.iterdir()):
                self._safe(directory)
                self._safe(directory / 'manifest.json')
                manifest = self._manifest(directory)
                if manifest.key in result or manifest.key != (model_dir.name, directory.name):
                    raise RegistryError('Duplicate or mismatched model identity')
                result[manifest.key] = (manifest, directory)
        return result

    def active_versions(self):
        if not self.activation_file.exists():
            return set()
        data = read_json(self.activation_file)
        if not isinstance(data, dict) or set(data) != {'active'} or not isinstance(data['active'], list):
            raise RegistryError('Invalid activation metadata')
        active = set()
        for entry in data['active']:
            if not isinstance(entry, dict) or set(entry) != {'model_id', 'version'}:
                raise RegistryError('Invalid activation identity')
            self._check_identity(entry['model_id'], entry['version'])
            key = entry['model_id'], entry['version']
            if key in active:
                raise RegistryError('Duplicate activation identity')
            active.add(key)
        return active

    def catalog(self):
        active = self.active_versions()
        rows = []
        for manifest, _ in self.entries().values():
            rows.append({
                'name': f'{manifest.model_id}-v{manifest.version.replace(".", "-")}',
                'display_name': manifest.name, 'description': manifest.description,
                'model_id': manifest.model_id, 'version': manifest.version, 'sha256': manifest.sha256,
                'file': manifest.weight_file,
                'endpoint': f'/predict/{manifest.model_id}/{manifest.version}',
                'active': manifest.key in active,
            })
        return {'count': len(rows), 'models': rows}

    @staticmethod
    def _check_identity(model_id, version):
        if not isinstance(model_id, str) or not isinstance(version, str) or not re.fullmatch(MODEL_ID, model_id) or not re.fullmatch(VERSION, version):
            raise RegistryError('Invalid model identity')

    def assert_version_available(self, model_id, version):
        """Preflight only; future publisher must also atomically refuse overwrite."""
        self._check_identity(model_id, version)
        target = self.root / model_id / version
        self._safe(target)
        if target.exists():
            raise RegistryError('Immutable version already exists')
        return target

    @contextmanager
    def verified_snapshot(self, directory):
        """Shared integrity boundary for loading and future staged publication."""
        from .loaders.tensorflow import screen_model
        directory = Path(directory)
        if any(part.is_symlink() for part in (directory, *directory.parents)):
            raise RegistryError('Candidate symlinks are forbidden')
        manifest = self._manifest(directory)
        source = directory / manifest.weight_file
        before = fingerprint(source)
        with tempfile.TemporaryDirectory(prefix='deepct-verified-') as temporary:
            snapshot = Path(temporary) / manifest.weight_file
            digest = hashlib.sha256()
            size = 0
            descriptor = os.open(source, os.O_RDONLY | os.O_NOFOLLOW)
            with os.fdopen(descriptor, 'rb') as incoming, snapshot.open('wb') as outgoing:
                while chunk := incoming.read(1024 * 1024):
                    size += len(chunk)
                    if size > manifest.size_bytes:
                        raise RegistryError('Weight size mismatch')
                    digest.update(chunk)
                    outgoing.write(chunk)
            if size != manifest.size_bytes or digest.hexdigest() != manifest.sha256 or fingerprint(source) != before:
                raise RegistryError('Weight integrity verification failed')
            try:
                screen_model(snapshot)
            except (ValueError, OSError, KeyError) as exc:
                raise RegistryError('Model graph rejected') from exc
            yield manifest, snapshot

    def validate_candidate(self, directory):
        """Validate a staged version without activating or importing TensorFlow."""
        with self.verified_snapshot(directory) as (manifest, _):
            return manifest
