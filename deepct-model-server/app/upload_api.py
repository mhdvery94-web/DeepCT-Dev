"""Management JSON and independent capability-only byte transport."""
from fastapi import BackgroundTasks, Depends, Header, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.concurrency import run_in_threadpool

from .registry import Manifest
from .uploads import CHUNK_BYTES, Uploads


def install_upload_routes(app, registry, origins=(), compatibility=None):
    uploads = Uploads(registry, compatibility)
    app.state.uploads = uploads
    management = [Depends(app.state.management_auth)]
    if origins:
        app.add_middleware(CORSMiddleware, allow_origins=list(origins), allow_credentials=False,
                           allow_methods=['PUT'], allow_headers=['Authorization', 'Upload-Offset', 'Content-Type'])

    @app.post('/management/uploads', dependencies=management, status_code=201)
    def create(manifest: Manifest):
        return uploads.create(manifest)

    @app.get('/management/uploads/{identifier}', dependencies=management)
    def status(identifier: str):
        return uploads.public(uploads.read(identifier))

    @app.post('/management/uploads/{identifier}/{action}', dependencies=management)
    def action(identifier: str, action: str, background: BackgroundTasks):
        data, status = uploads.schedule(identifier, action, background)
        return JSONResponse(data, status_code=status)

    @app.put('/uploads/{identifier}')
    async def chunk(identifier: str, request: Request, upload_offset: int = Header(...), authorization: str = Header('')):
        token = authorization.removeprefix('Bearer ') if authorization.startswith('Bearer ') else ''
        def authorize():
            with registry.lock:
                uploads.authorize(uploads.read(identifier), token)

        await run_in_threadpool(authorize)
        data = bytearray()
        async for piece in request.stream():
            if len(data) + len(piece) > CHUNK_BYTES:
                raise HTTPException(413, 'Chunk exceeds 4 MiB')
            data.extend(piece)
        # chunk reauthorizes and checks the current offset under both locks.
        # Neither lock contention nor synchronous disk/fsync may block ASGI.
        return await run_in_threadpool(uploads.chunk, identifier, token, upload_offset, data)
