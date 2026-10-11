import json
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

from app.loaders.tensorflow import TensorFlowLoader, screen_graph


def test_deployed_hdf5_graph_is_accepted_without_tensorflow():
    graph = json.loads((Path(__file__).parent / 'fixtures/deployed-model-config.json').read_text())
    screen_graph(graph)
    assert 'tensorflow' not in sys.modules


def test_loader_uses_safe_mode_compile_false_and_approved_custom_layers(model_tree, monkeypatch):
    from app.loaders import tensorflow as module
    _, _, directory, _ = model_tree
    def version(package):
        return {'tensorflow': '2.17.0', 'keras': '3.15.1'}[package]
    monkeypatch.setattr('importlib.metadata.version', version)
    sentinel = object()
    def load_model(path, *, custom_objects, compile, safe_mode):
        assert Path(path).name == 'model.h5'
        assert compile is False and safe_mode is True
        assert set(custom_objects) == {'TimeMean', 'TimeLast', 'SkipFusion', 'Custom>TimeMean', 'Custom>TimeLast', 'Custom>SkipFusion'}
        return sentinel
    fake = SimpleNamespace(keras=SimpleNamespace(
        layers=SimpleNamespace(Layer=object), models=SimpleNamespace(load_model=load_model),
        backend=SimpleNamespace(clear_session=lambda: None),
    ))
    monkeypatch.setitem(sys.modules, 'tensorflow', fake)
    assert TensorFlowLoader().load(directory / 'model.h5') is sentinel


def test_loader_refuses_unreviewed_runtime_before_tensorflow_import(model_tree, monkeypatch):
    _, _, directory, _ = model_tree
    monkeypatch.setattr('importlib.metadata.version', lambda package: '0.0.0')
    with pytest.raises(ValueError):
        TensorFlowLoader().load(directory / 'model.h5')
