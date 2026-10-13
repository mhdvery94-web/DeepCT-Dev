"""Real HTTP worker; only model execution/provider are synthetic CPU boundaries.

Run with --runtime pointing outside the checkout; never against live weights.
Upload verification, persistence, capability auth and unconfigured compatibility
remain the production code. No TensorFlow imports or GPU calls occur.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import h5py
import numpy as np
import uvicorn
from fastapi import Request

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.config import Settings
from app.main import create_app
from app.registry import Registry

parser = argparse.ArgumentParser()
parser.add_argument('--runtime', type=Path, required=True)
args = parser.parse_args()
config = dict(line.split('=', 1) for line in (args.runtime / 'laravel.env').read_text().splitlines())
root = args.runtime / 'models'
directory = root / 'task6-ct' / '1.0.0'
directory.mkdir(parents=True, exist_ok=True)
weight = directory / 'model.h5'
if not weight.exists():
    with h5py.File(weight, 'w') as handle:
        handle.attrs['model_config'] = json.dumps({'class_name': 'Functional', 'config': {'layers': []}})
        handle.create_dataset('synthetic', data=np.zeros((2 * 1024 * 1024,), dtype=np.float32))
manifest = dict(schema_version=1, model_id='task6-ct', version='1.0.0', name='CPU execution fixture',
    description='Synthetic local model; no scientific validation', framework='tensorflow', adapter='ginet-tcd-v1',
    weight_file='model.h5', sha256=hashlib.sha256(weight.read_bytes()).hexdigest(), size_bytes=weight.stat().st_size,
    input=dict(width=1024, height=1024, dtype='uint16', time_scalar=0.5))
(directory / 'manifest.json').write_text(json.dumps(manifest))
activation = args.runtime / 'activation.json'
activation.write_text(json.dumps({'active': [{'model_id': 'task6-ct', 'version': '1.0.0'}]}))


class CpuModel:
    def predict(self, inputs, verbose=0):
        return (inputs[0][:, 0] + inputs[0][:, 1]) / 2


class CpuLoader:
    def load(self, path):
        return CpuModel()

    def release(self):
        pass


app = create_app(Settings(models_root=root, activation_file=activation,
    inference_token=config['TUF_INFERENCE_TOKEN'], management_token=config['TUF_MANAGEMENT_TOKEN'],
    upload_origins=('http://localhost:3016',)), Registry(root, activation, loader=CpuLoader()))


@app.middleware('http')
async def unavailable(request, call_next):
    if (args.runtime / 'worker-unavailable').exists() and request.url.path.startswith('/management/'):
        from fastapi.responses import JSONResponse
        return JSONResponse({'detail': 'Local unavailable-worker boundary'}, status_code=503)
    return await call_next(request)


@app.post('/api/chat')
async def provider(request: Request):
    if (args.runtime / 'provider-unavailable').exists():
        from fastapi.responses import JSONResponse
        return JSONResponse({'detail': 'Synthetic provider unavailable'}, status_code=503)
    payload = await request.json()
    assert payload['stream'] is False
    assert payload['options']['num_ctx'] == 2048
    # Delay gives acceptance enough time to verify unrelated API/CT responsiveness.
    import asyncio
    await asyncio.sleep(2)
    return {'done': True, 'done_reason': 'stop',
        'message': {'content': 'Synthetic provider reply. Verify the separately supplied CT evidence.'},
        'eval_count': 12, 'total_duration': 2_000_000_000}


uvicorn.run(app, host='0.0.0.0', port=9116, access_log=False)
