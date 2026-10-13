"""Factory: uvicorn app.main:create_app --factory --workers 1 (no reload)."""
import secrets
import logging
import re

from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .adapters.ginet_tcd import encode_prediction, prepare_inputs
from .config import Settings
from .registry import Registry, RegistryError

logger = logging.getLogger(__name__)


def diagnostic_identity(value, pattern):
    return value if re.fullmatch(pattern, value) else 'invalid'


def bearer_dependency(expected):
    security = HTTPBearer(auto_error=False)
    def authorize(credentials: HTTPAuthorizationCredentials | None = Depends(security)):
        if credentials is None or not secrets.compare_digest(credentials.credentials.encode(), expected.encode()):
            raise HTTPException(status_code=401, detail='Unauthorized', headers={'WWW-Authenticate': 'Bearer'})
    return authorize


def create_app(settings=None, registry=None):
    settings = settings or Settings.from_env()
    registry = registry or Registry(settings.models_root, settings.activation_file)
    app = FastAPI(title='DeepCT Model Server', docs_url=None, redoc_url=None, openapi_url=None)
    inference = bearer_dependency(settings.inference_token)
    # Task 5 management routes must use this separate dependency.
    app.state.management_auth = bearer_dependency(settings.management_token)
    app.state.registry = registry

    @app.get('/')
    def health():
        return {'service': 'deepct-model-server', 'status': 'running'}

    @app.get('/models', dependencies=[Depends(inference)])
    def catalog():
        try:
            return registry.catalog()
        except (RegistryError, OSError):
            return JSONResponse(status_code=503, content={'detail': 'Model catalog unavailable'})

    @app.post('/predict/{model_id}/{version}', dependencies=[Depends(inference)])
    def predict(model_id: str, version: str, file_t0: UploadFile = File(...),
                file_t2: UploadFile = File(...), time_scalar: float = Form(...)):
        frames = []
        for upload in (file_t0, file_t2):
            frame = upload.file.read(settings.max_upload_bytes + 1)
            if len(frame) > settings.max_upload_bytes:
                raise HTTPException(status_code=413, detail='Image upload too large')
            frames.append(frame)
        try:
            inputs = prepare_inputs(*frames, time_scalar)
        except ValueError:
            raise HTTPException(status_code=422, detail='Expected uint16 TIFF frames and midpoint time') from None
        try:
            output = registry.predict(model_id, version, inputs)
            image = encode_prediction(output)
        except RegistryError:
            raise HTTPException(status_code=409, detail='Model version unavailable or invalid') from None
        except Exception as exc:
            # Never log exception text/tracebacks: loaders may include paths,
            # credentials or input data. Route identifiers are untrusted too.
            logger.error('Inference failed model=%s version=%s category=%s',
                diagnostic_identity(model_id, r'[a-z0-9][a-z0-9-]{0,79}'),
                diagnostic_identity(version, r'\d{1,10}\.\d{1,10}\.\d{1,10}'),
                diagnostic_identity(type(exc).__name__, r'[A-Za-z][A-Za-z0-9_]{0,79}'))
            raise HTTPException(status_code=503, detail='Inference unavailable') from None
        return Response(image, media_type='image/tiff', headers={
            'Content-Disposition': f'attachment; filename="{model_id}-v{version}-prediction.tif"',
        })

    from .upload_api import install_upload_routes
    from .compatibility import Compatibility
    install_upload_routes(app, registry, settings.upload_origins, Compatibility(registry, settings.compatibility_gpu_bytes, settings.compatibility_address_bytes))
    return app
