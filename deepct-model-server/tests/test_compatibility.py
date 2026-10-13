"""Containment fails closed without ever importing or invoking real TensorFlow."""
import subprocess
import sys
from types import SimpleNamespace

import numpy as np

import pytest
from fastapi import HTTPException

from app.compatibility import Compatibility
from app.registry import Registry
from app.config import Settings


@pytest.mark.parametrize('cpu_output,cpu_weight', [(False, False), (True, False), (False, True)])
def test_child_calls_tensor_model_without_cpu_dataset_and_rejects_cpu_placement(monkeypatch, cpu_output, cpu_weight):
    """CPU-only boundary double: predict's dataset path is forbidden.

    Real child control flow and adapter encoding run; no TensorFlow/GPU load.
    Returning a CPU output or weight must fail even when the probe is GPU.
    """
    from app import compatibility_child

    class Tensor:
        def __init__(self, data, cpu=False):
            self.data = np.asarray(data)
            self.device = '/job:localhost/replica:0/task:0/device:' + ('CPU:0' if cpu else 'GPU:0')

        def numpy(self):
            return self.data

    class Device:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

    class Model:
        weights = [SimpleNamespace(value=Tensor([1], cpu_weight))]

        def predict(self, *args, **kwargs):
            pytest.fail('model.predict creates a CPU-only RangeDataset under strict GPU placement')

        def __call__(self, inputs, *, training):
            assert training is False
            assert all(isinstance(value, Tensor) for value in inputs)
            assert inputs[0].data.shape == (1, 2, 1024, 1024, 1)
            assert inputs[0].data.dtype == np.float32
            assert inputs[1].data.tolist() == [[0.5]]
            return Tensor(np.zeros((1, 1024, 1024, 1), dtype=np.float32), cpu_output)

    def strict(value):
        assert value is False, 'Never allow CPU fallback'

    tf = SimpleNamespace(
        config=SimpleNamespace(list_physical_devices=lambda kind: ['gpu'],
            set_visible_devices=lambda *args: None,
            set_logical_device_configuration=lambda *args: None,
            LogicalDeviceConfiguration=lambda **kwargs: kwargs,
            set_soft_device_placement=strict),
        device=lambda name: Device(), ones=lambda shape: Tensor(np.ones(shape)),
        linalg=SimpleNamespace(matmul=lambda *args: Tensor([[1]])),
        convert_to_tensor=Tensor,
    )
    monkeypatch.setitem(sys.modules, 'tensorflow', tf)
    monkeypatch.setattr('app.loaders.tensorflow.TensorFlowLoader.load', lambda *args: Model())
    monkeypatch.setattr(compatibility_child.resource, 'setrlimit', lambda *args: None)
    monkeypatch.setattr(sys, 'argv', ['child', '/private/model.keras', str(1024**3), str(2 * 1024**3)])
    assert compatibility_child.main() == (1 if cpu_output or cpu_weight else 0)


def test_unconfigured_address_limit_never_starts_gpu_probe(model_tree, monkeypatch):
    root, activation, directory, _ = model_tree
    monkeypatch.setattr('app.compatibility.gpu_free_bytes', lambda: pytest.fail('Missing containment must reject before GPU probing'))
    with pytest.raises(HTTPException) as error:
        Compatibility(Registry(root, activation), 1024**3)(directory)
    assert error.value.status_code == 503


def test_child_applies_limits_before_numerical_imports():
    # A fresh CPU-only process intercepts imports, checking actual OS limits at
    # the first NumPy import. No TensorFlow, GPU, or persistent process involved.
    code = '''
import builtins, resource, sys
from app.compatibility_child import main
sys.argv = ['compatibility_child', '/unused', '1073741824', '2147483648']
original = builtins.__import__
def checked(name, *args, **kwargs):
    if name == 'numpy':
        assert resource.getrlimit(resource.RLIMIT_AS) == (2147483648, 2147483648)
        assert resource.getrlimit(resource.RLIMIT_CORE) == (0, 0)
        raise SystemExit(0)
    return original(name, *args, **kwargs)
builtins.__import__ = checked
main()
raise SystemExit(2)
'''
    result = subprocess.run([sys.executable, '-c', code], capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize('value', ['', 'invalid', '-1', '0'])
def test_invalid_containment_config_retains_ct_service_but_disables_compatibility(monkeypatch, value):
    monkeypatch.setenv('DEEPCT_INFERENCE_TOKEN', 'inference')
    monkeypatch.setenv('DEEPCT_MANAGEMENT_TOKEN', 'management')
    monkeypatch.setenv('DEEPCT_COMPATIBILITY_GPU_BYTES', value)
    monkeypatch.setenv('DEEPCT_COMPATIBILITY_ADDRESS_BYTES', value)
    settings = Settings.from_env()
    assert settings.compatibility_gpu_bytes is None
    assert settings.compatibility_address_bytes is None


def test_timeout_or_failed_child_cannot_pass_compatibility(model_tree, monkeypatch):
    root, activation, directory, _ = model_tree
    monkeypatch.setattr('app.compatibility.gpu_free_bytes', lambda: 2 * 1024**3)
    runner = Compatibility(Registry(root, activation), 1024**3, 2 * 1024**3)
    def timeout(*args, **kwargs):
        raise subprocess.TimeoutExpired(args[0], 60)
    monkeypatch.setattr('app.compatibility.subprocess.run', timeout)
    with pytest.raises(HTTPException) as failure:
        runner(directory)
    assert failure.value.status_code == 503
    monkeypatch.setattr('app.compatibility.subprocess.run', lambda *args, **kwargs: subprocess.CompletedProcess(args, 1))
    with pytest.raises(HTTPException) as failure:
        runner(directory)
    assert failure.value.status_code == 503
    assert not activation.exists()
