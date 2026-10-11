import hashlib
import json

import h5py
import pytest


@pytest.fixture
def model_tree(tmp_path):
    root = tmp_path / 'deepct-models'
    directory = root / 'ginet-tcd-revisi' / '1.0.0'
    directory.mkdir(parents=True)
    weights = directory / 'model.h5'
    with h5py.File(weights, 'w') as handle:
        handle.attrs['model_config'] = json.dumps({
            'class_name': 'Functional', 'config': {'layers': [
                {'class_name': 'InputLayer', 'config': {'name': 'input'}}
            ]}
        })
    manifest = {
        'schema_version': 1, 'model_id': 'ginet-tcd-revisi', 'version': '1.0.0',
        'name': 'GINet TC-D Revisi', 'description': 'Imported test fixture',
        'framework': 'tensorflow', 'adapter': 'ginet-tcd-v1',
        'weight_file': 'model.h5', 'sha256': hashlib.sha256(weights.read_bytes()).hexdigest(),
        'size_bytes': weights.stat().st_size,
        'input': {'width': 1024, 'height': 1024, 'dtype': 'uint16', 'time_scalar': 0.5},
    }
    (directory / 'manifest.json').write_text(json.dumps(manifest))
    return root, tmp_path / 'activation.json', directory, manifest


def activate(path, version='1.0.0'):
    path.write_text(json.dumps({'active': [{'model_id': 'ginet-tcd-revisi', 'version': version}]}))
