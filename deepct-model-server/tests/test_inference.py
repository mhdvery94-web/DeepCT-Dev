import hashlib
import json
import threading
from concurrent.futures import ThreadPoolExecutor

import pytest

from app.registry import Registry, RegistryError
from conftest import activate


class ArithmeticModel:
    def __init__(self, loader):
        self.loader = loader

    def predict(self, inputs, verbose):
        assert verbose == 0
        assert self.loader.running.acquire(blocking=False), 'concurrent inference'
        try:
            threading.Event().wait(0.01)
            return sum(inputs)
        finally:
            self.loader.running.release()


class Loader:
    def __init__(self):
        self.running = threading.Lock()
        self.loads = 0
        self.releases = 0
    def load(self, path):
        self.loads += 1
        assert path.exists()
        return ArithmeticModel(self)
    def release(self):
        self.releases += 1


def test_reuses_single_model_and_serializes_concurrent_inference(model_tree):
    root, activation, _, _ = model_tree
    activate(activation)
    loader = Loader()
    registry = Registry(root, activation, loader=loader)
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda x: registry.predict('ginet-tcd-revisi', '1.0.0', [x, 2]), range(12)))
    assert results == list(range(2, 14))
    assert loader.loads == 1


def test_inactive_or_missing_version_never_loads(model_tree):
    root, activation, _, _ = model_tree
    loader = Loader()
    registry = Registry(root, activation, loader=loader)
    for version in ['1.0.0', '2.0.0']:
        with pytest.raises(RegistryError):
            registry.predict('ginet-tcd-revisi', version, [1, 2])
    assert loader.loads == 0


def test_same_size_tamper_invalidates_cached_model(model_tree):
    root, activation, directory, _ = model_tree
    activate(activation)
    loader = Loader()
    registry = Registry(root, activation, loader=loader)
    assert registry.predict('ginet-tcd-revisi', '1.0.0', [1, 2]) == 3
    weights = directory / 'model.h5'
    original = weights.read_bytes()
    weights.write_bytes(original[:-1] + bytes([original[-1] ^ 1]))
    with pytest.raises(RegistryError):
        registry.predict('ginet-tcd-revisi', '1.0.0', [1, 2])
    assert loader.loads == 1


def test_switching_version_releases_previous_model(model_tree):
    import shutil
    root, activation, directory, manifest = model_tree
    second = directory.parent / '2.0.0'
    shutil.copytree(directory, second)
    manifest['version'] = '2.0.0'
    (second / 'manifest.json').write_text(json.dumps(manifest))
    loader = Loader()
    registry = Registry(root, activation, loader=loader)
    activate(activation)
    assert registry.predict('ginet-tcd-revisi', '1.0.0', [1, 2]) == 3
    activate(activation, '2.0.0')
    assert registry.predict('ginet-tcd-revisi', '2.0.0', [3, 4]) == 7
    assert loader.loads == 2 and loader.releases == 1


def test_snapshot_loaded_is_exact_verified_bytes_despite_source_replacement(model_tree):
    root, activation, directory, manifest = model_tree
    activate(activation)
    class ReplacingLoader(Loader):
        def load(self, path):
            (directory / 'model.h5').write_bytes(b'corrupt')
            assert hashlib.sha256(path.read_bytes()).hexdigest() == manifest['sha256']
            return super().load(path)
    assert Registry(root, activation, loader=ReplacingLoader()).predict('ginet-tcd-revisi', '1.0.0', [1, 2]) == 3
