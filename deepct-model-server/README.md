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

Configure the environment variables in `.env.example` through the process
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
Only the management publisher may write new version directories. Invalid
registry metadata fails the catalog closed; catalog reads small manifests and
file stats only, without hashing weights or importing TensorFlow.

Activation is separate, outside this root, with an initially absent/empty file:

```json
{"active": []}
```

After an authorized compatibility test, management code can atomically
replace that file with explicit identities, for example
`{"active":[{"model_id":"ginet-tcd-revisi","version":"1.0.0"}]}`.
Publication alone never activates a version; ordinary inference refuses every
inactive version. The catalog includes inactive versions with `active: false`.
Activation is distinct from the one model currently resident in GPU memory.

Management integration seams: `validate_candidate(directory)` validates a staging
directory and returns its manifest; `verified_snapshot(directory)` yields a
private, hashed and screened copy usable for pre-activation compatibility tests;
`assert_version_available(id, version)` performs preflight checks. Publication
must implement atomic no-replace semantics and revalidation; the preflight is
not a concurrency guarantee. Use `registry.lock` for management changes that
must not race inference. `app.state.management_auth` is the separate bearer
dependency. Management uses durable resumable sessions in the sibling `.incoming`
directory. `POST /management/uploads` accepts a strict manifest (maximum 10 GiB),
and returns a 15-minute session-scoped capability. Laravel owns admin/ownership
authorization and renewal. Clients PUT at most 4 MiB directly to
`/uploads/{uuid}` with `Authorization: Bearer <capability>` and `Upload-Offset`.
No login credential or byte stream goes through Laravel. Configure exact browser
origins with `DEEPCT_UPLOAD_ORIGINS`; HTTPS ingress must forward the upload route,
allow these headers and PUT/OPTIONS, and enforce a 4 MiB request body limit for it.
Management routes must remain on the trusted internal service path.

`GET /management/uploads/{uuid}` reconciles durable state. POST actions are
`renew`, `cancel`, `finalize`, `test`, `publish`, `activate`, `deactivate`.
Validation/test/publication return 202 and run as owned background work; poll
until `operation` disappears and inspect `last_error`. Restart returns interrupted
validation to a retryable state; committed offsets survive, and uncommitted tail
bytes are truncated. Disk admission reserves 2 GiB plus all outstanding upload
bytes and any verification snapshot. Publication is atomic Linux rename-no-replace,
retains immutable tuple identity, and leaves the candidate inactive.

Compatibility requires positive trusted `DEEPCT_COMPATIBILITY_GPU_BYTES` and
`DEEPCT_COMPATIBILITY_ADDRESS_BYTES`. Missing/invalid budgets, unverifiable GPU
capacity, timeout or nonzero child exit leave compatibility unavailable. Before
NumPy/TensorFlow imports the owned child sets RLIMIT_AS and RLIMIT_CORE=0, then
sets TensorFlow's logical GPU memory limit before initialization and refuses CPU
placement. The 60-second child timeout terminates only that owned child.
RLIMIT_AS bounds virtual address space, not resident RAM or CUDA mappings. The
budgets have no guessed defaults: Task 6 must validate safe workable mappings;
otherwise retain unavailable until tested cgroup/container containment exists.
GPU preflight is not a reservation against unrelated processes. Compatibility
is runtime/shape evidence, never scientific acceptance or automatic activation.

Laravel config uses `TUF_INTERNAL_URL` (root-only), `TUF_PUBLIC_UPLOAD_URL`
(HTTPS; an ingress prefix is allowed), `TUF_MANAGEMENT_TOKEN`, and
`TUF_INFERENCE_TOKEN`. The credentials must differ. Availability changes commit
a local admission barrier before remote mutation. Timeout leaves it in place;
configured authenticated catalog reconciliation clears it only after observing
the exact tuple's desired availability. An old-state observation is insufficient.
Existing manually registered aliases block availability changes with a conflict;
their history is never relinked. Pending/processing CT jobs block deactivation.

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
