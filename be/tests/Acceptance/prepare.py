"""Create/reuse private local acceptance config; never print secret values.

Run with the model-server Python environment for NumPy/tifffile. All credentials
are local synthetic or reused privately from this checkout's local DB config.
"""
import base64
import io
import json
import os
import secrets
import subprocess
import zipfile
from pathlib import Path

import numpy as np
import tifffile

backend = Path(__file__).resolve().parents[2]
runtime = Path('/workspace/.deepct-runtime/task6')
runtime.mkdir(parents=True, exist_ok=True, mode=0o700)
os.chmod(runtime, 0o700)
gateway = subprocess.check_output(['docker', 'inspect', '--format',
    '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}', 'deepct-api'], text=True).strip()
if not (runtime / 'laravel.env').exists():
    values = {}
    for line in (backend / '.env').read_text().splitlines():
        if line.startswith(('DB_HOST=', 'DB_PORT=', 'DB_USERNAME=', 'DB_PASSWORD=')):
            name, value = line.split('=', 1)
            values[name] = value.strip('"\'')
    values.update(APP_ENV='testing', APP_DEBUG='false',
        APP_KEY='base64:' + base64.b64encode(secrets.token_bytes(32)).decode(),
        DB_CONNECTION='mysql', DB_DATABASE='db_aict_task6',
        APP_CONFIG_CACHE='/tmp/task6-config.php', APP_ROUTES_CACHE='/tmp/task6-routes.php',
        APP_URL='http://localhost:9016/staging', CACHE_STORE='file', SESSION_DRIVER='file',
        QUEUE_CONNECTION='database', DB_QUEUE='task6-ct', AI_ASSISTANT_ENABLED='true',
        AI_OLLAMA_BASE_URL=f'http://{gateway}:9116', TUF_INTERNAL_URL=f'http://{gateway}:9116',
        TUF_PUBLIC_UPLOAD_URL='https://localhost:9446/tuf',
        TUF_MANAGEMENT_TOKEN='task6-management-' + secrets.token_hex(12),
        TUF_INFERENCE_TOKEN='task6-inference-' + secrets.token_hex(12),
        TASK6_STORAGE=str(backend / 'storage/task6'),
        NO_PROXY=f'localhost,127.0.0.1,{gateway}', no_proxy=f'localhost,127.0.0.1,{gateway}')
    (runtime / 'laravel.env').write_text(''.join(f'{name}={value}\n' for name, value in values.items()))
    os.chmod(runtime / 'laravel.env', 0o600)
if not (runtime / 'accounts.json').exists():
    (runtime / 'accounts.json').write_text(json.dumps({'password': 'Task6-' + secrets.token_hex(12)}))
    os.chmod(runtime / 'accounts.json', 0o600)
if not (runtime / 'cert.pem').exists():
    subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
        '-keyout', str(runtime / 'key.pem'), '-out', str(runtime / 'cert.pem'), '-days', '2',
        '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1'],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.chmod(runtime / 'key.pem', 0o600)
with zipfile.ZipFile(runtime / 'frames.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for filename, value in [('frame_001.tif', 0), ('frame_003.tif', 65535)]:
        frame = io.BytesIO()
        tifffile.imwrite(frame, np.full((1024, 1024), value, dtype=np.uint16))
        archive.writestr(filename, frame.getvalue())
exclude = backend.parent / '.git/info/exclude'
existing = exclude.read_text()
if '/be/storage/task6/' not in existing:
    exclude.write_text(existing + '\n/be/storage/task6/\n')
print('Private acceptance configuration and synthetic TIFF archive prepared; existing identities preserved.')
