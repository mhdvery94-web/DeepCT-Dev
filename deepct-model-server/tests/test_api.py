import io

import numpy as np
import pytest
import tifffile
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.registry import Registry
from conftest import activate


def settings(root, activation, **overrides):
    return Settings(models_root=root, activation_file=activation,
                    inference_token='test-inference-token', management_token='test-management-token', **overrides)


@pytest.mark.parametrize('inference,management', [('', 'other'), ('a', ''), ('same', 'same'), (' ', 'other'), ('tökén', 'other')])
def test_missing_or_shared_credentials_fail_closed(tmp_path, inference, management):
    with pytest.raises(ValueError):
        Settings(models_root=tmp_path / 'models', activation_file=tmp_path / 'active.json',
                 inference_token=inference, management_token=management)


def test_health_minimal_and_catalog_requires_correct_bearer(model_tree):
    root, activation, _, _ = model_tree
    with TestClient(create_app(settings(root, activation))) as client:
        assert client.get('/').json() == {'service': 'deepct-model-server', 'status': 'running'}
        for headers in [{}, {'Authorization': 'Bearer test-management-token'}, {'Authorization': 'Bearer wrong'}]:
            assert client.get('/models', headers=headers).status_code == 401
        response = client.get('/models', headers={'Authorization': 'Bearer test-inference-token'})
        assert response.status_code == 200
        assert response.json()['models'][0]['name'] == 'ginet-tcd-revisi-v1-0-0'


def test_multipart_prediction_preserves_tiff_contract(model_tree):
    root, activation, _, _ = model_tree
    activate(activation)
    class Model:
        def predict(self, inputs, verbose):
            pair, time = inputs
            assert time.tolist() == [[0.5]]
            return (pair[:, 0] + pair[:, 1]) / 2
    class Loader:
        def load(self, path):
            return Model()
        def release(self):
            pass
    registry = Registry(root, activation, loader=Loader())
    first, second = io.BytesIO(), io.BytesIO()
    tifffile.imwrite(first, np.zeros((2, 2), dtype=np.uint16))
    tifffile.imwrite(second, np.full((2, 2), 65535, dtype=np.uint16))
    files = {'file_t0': ('first.tiff', first.getvalue(), 'image/tiff'),
             'file_t2': ('second.tiff', second.getvalue(), 'image/tiff')}
    endpoint = '/predict/ginet-tcd-revisi/1.0.0'
    with TestClient(create_app(settings(root, activation), registry)) as client:
        assert client.post(endpoint, files=files, data={'time_scalar': '0.5'}).status_code == 401
        headers = {'Authorization': 'Bearer test-inference-token'}
        response = client.post(endpoint, headers=headers, files=files, data={'time_scalar': '0.5'})
        assert response.status_code == 200 and response.headers['content-type'] == 'image/tiff'
        pixels = tifffile.imread(io.BytesIO(response.content))
        assert pixels.shape == (1024, 1024) and np.all(pixels == 32767)
        assert client.post(endpoint, headers=headers, files=files, data={'time_scalar': '0.4'}).status_code == 422
        activation.unlink()
        assert client.post(endpoint, headers=headers, files=files, data={'time_scalar': '0.5'}).status_code == 409


def test_registry_error_does_not_leak_filesystem_paths(model_tree):
    root, activation, directory, _ = model_tree
    (directory / 'manifest.json').write_text('bad')
    with TestClient(create_app(settings(root, activation))) as client:
        response = client.get('/models', headers={'Authorization': 'Bearer test-inference-token'})
        assert response.status_code == 503
        assert str(root) not in response.text
