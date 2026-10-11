# DeepCT versioned model worker

CPU development (TensorFlow stays absent): `uv sync --locked`, then
`uv run --locked pytest`. Python 3.11 is the deployment target; the CPU suite
also supports Python 3.12. The inference extra pins the inspected TUF runtime,
TensorFlow 2.17.0 and Keras 3.15.1. Install it only in a separately prepared
worker environment with `uv sync --locked --extra inference --no-dev`.
No dependency installation into the existing production worker is implied.
`uv.lock` is the authoritative hashed resolution; `requirements.lock` exports
the deployment profile including inference (not development dependencies).
Regenerate it with `uv export --locked --extra inference --no-dev --format
requirements-txt --no-header --output-file requirements.lock --quiet`. A prepared deployment
virtual environment can alternatively install it with
`uv pip sync --require-hashes requirements.lock`. This export has been checked,
but the TensorFlow deployment installation and live loading have not been run.

Configure the four environment variables in `.env.example` through the process
supervisor. Both bearer tokens are required, nonempty and distinct. The app
does not read `.env` automatically. Run exactly one process, without reload:

```
uv run --locked --no-sync uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8000 --workers 1
```

Terminate TLS at the existing approved HTTPS ingress. Limit incoming request
bodies there (including multipart overhead); the application limits each image
read to 32 MiB and decoded input to 16 million pixels. Multipart parsing occurs
before route execution, so ingress limits are necessary to bound spooled bytes.

`GET /` returns only service/status. `GET /models` and
`POST /predict/{model_id}/{version}` require the inference bearer. Predictions
use multipart `file_t0`, `file_t2`, `time_scalar=0.5` and return `image/tiff`.
Catalog machine names remain compatible with Laravel, e.g.
`ginet-tcd-revisi-v1-0-0`; `display_name` carries the human label.

Each published directory is exactly
`deepct-models/<model_id>/<major.minor.patch>/{manifest.json,model.h5|model.keras}`.
The example manifest records the imported legacy version's verified checksum,
not a newly validated scientific release. No weights are stored in Git.
Treat published directories as immutable and make them read-only to the worker.
Only a future management publisher may write new version directories. Invalid
registry metadata fails the catalog closed; catalog reads small manifests and
file stats only, without hashing weights or importing TensorFlow.

Activation is separate, outside this root, with an initially absent/empty file:

```json
{"active": []}
```

After an authorized compatibility test, future management code can atomically
replace that file with explicit identities, for example
`{"active":[{"model_id":"ginet-tcd-revisi","version":"1.0.0"}]}`.
Publication alone never activates a version; ordinary inference refuses every
inactive version. The catalog includes inactive versions with `active: false`.
Activation is distinct from the one model currently resident in GPU memory.

Task 5 integration seams: `validate_candidate(directory)` validates a staging
directory and returns its manifest; `verified_snapshot(directory)` yields a
private, hashed and screened copy usable for pre-activation compatibility tests;
`assert_version_available(id, version)` performs preflight checks. Publication
must implement atomic no-replace semantics and revalidation; the preflight is
not a concurrency guarantee. Use `registry.lock` for management changes that
must not race inference. `app.state.management_auth` is the separate bearer
dependency; there are deliberately no upload, publish or activation routes yet.

Only the selected model is loaded. Its checksum and graph are checked before
load, from a private snapshot to avoid a source-replacement race. Manifest and
weight device/inode/size/mtime/ctime invalidate the cache. Deactivation is read
on each call. The single process lock spans switching and prediction. Keep
registry ownership restricted: stat invalidation is not protection against a
privileged writer able to replace both the manifest and its weights.

Graph screening recursively restricts classes, modules, registered custom
objects and activations. HDF5 soft/external links and external/virtual storage
are rejected. Keras archives accept only bounded config/metadata/weights members,
reject duplicates, symlinks, traversal and excessive compression. Only approved
TimeMean, TimeLast and SkipFusion implementations are supplied to Keras, with
`compile=False, safe_mode=True`; HDF5 safety does not depend on safe_mode alone.
This is an allowlist boundary, not an operating-system sandbox for arbitrary
untrusted models. A separate constrained worker remains appropriate defense
in depth before enabling remote management uploads.

The deployed graph fixture contains metadata only. Adapter tests use generated
uint16 TIFFs and CPU arithmetic. Actual TensorFlow deserialization, GPU capacity,
real image parity and scientific acceptance remain Task 6 gates. Do not swap the
production worker, delete original weights, or stop notebook GPU processes.
