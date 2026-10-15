# DeepCT versioned model worker

CPU development (TensorFlow stays absent): `uv sync --locked`, then
`uv run --locked pytest`. Python 3.11 is the deployment target; the CPU suite
also supports Python 3.12. The inference extra pins the inspected TUF runtime,
TensorFlow 2.17.0 and Keras 3.15.1. Install it only in a separately prepared
worker environment with `uv sync --locked --extra inference --no-dev`.
No dependency installation into the existing production worker is implied.
Required CI uses Python 3.11 and `requirements-cpu.lock` with `--require-hashes`;
TensorFlow/NVIDIA are forbidden in that job. The optional Linux GPU staging
profile `requirements-cuda.lock` adds official `tensorflow[and-cuda]` extras
while preserving all existing inference pins. See [release instructions](../docs/RELEASE.md)
for isolated installation, containment, Unix-socket gateways and rollback.
`uv.lock` is the authoritative hashed resolution; `requirements.lock` exports
the deployment profile including inference (not development dependencies).
Regenerate it with `uv export --locked --extra inference --no-dev --format
requirements-txt --no-header --output-file requirements.lock --quiet`. A prepared deployment
virtual environment can alternatively install it with
`uv pip sync --require-hashes requirements.lock`. This export has been checked,
but neither export nor `pip check` proves that CUDA is available in a new venv.
The controller records live device/loader/parity evidence separately; base TF
without the CUDA extras returned an empty GPU device list in staging.

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
budgets have no guessed defaults: the tested staging profile uses GPU 5 GiB,
AS 24 GiB, cgroup RAM 4 GiB/no swap/128 tasks. Preserve containment and validate
the new venv device/child path before enabling compatibility.
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
uint16 TIFFs and CPU arithmetic. Actual TensorFlow deserialization and device
placement require controller runtime
evidence. The measured compiled/legacy maxabs 1 is not accepted scientific
parity; arbitrary-model UAT and scientific acceptance remain release gates. Do not swap the
production worker, delete original weights, or stop notebook GPU processes.

### Private GPU assistant gateway

The assistant is disabled unless `DEEPCT_ASSISTANT_TOKEN` is configured. This
bearer must differ from the inference, management and optional legacy credentials.
Laravel keeps user authorization and sends its metadata-only messages to
`POST /assistant/api/chat` through the existing private UDS/Caddy ingress. Do not
publish Ollama directly. The gateway connects only to `127.0.0.1:11435` using HTTP
without environment proxies, and only runs the deployed `deepseek-r1:7b` model.
It forces `think: true`, `stream: false`, `keep_alive: 0`; accepts at most 12,000
UTF-8 bytes across message contents and a 64 KiB JSON body; and bounds context
at 16,384, output at 2,048 and CPU threads at 16. Messages accept only text and
system/user/assistant roles. Thinking fields and provider diagnostics are never
returned or logged. Laravel removes a leading reasoning block if the provider
includes one in content.

Configure `DEEPCT_GPU_LEASE_PATH` to a local file in an existing private state
directory and `DEEPCT_ASSISTANT_GPU_BYTES` to the measured free-VRAM admission
threshold. Missing GPU capacity/configuration fails closed; there is no CPU
fallback. The same nonblocking file lease covers registry prediction (in addition
to its existing registry lock), compatibility work including its owned child,
assistant generation and legacy prediction forwarding. Registry/compatibility
lock order is registry lock then GPU lease. The compatibility child does not
reacquire the lease held by its parent. Before dispatch, compatibility persists
the unsafe marker too; only a confirmed, reaped child exit clears it. Parent death,
child timeout or ambiguous dispatch errors leave it intact. Use a local filesystem supporting `flock`;
all cooperating processes must use the same file, and direct legacy prediction
access must remain private. The lease coordinates work, not other processes'
existing allocations: the free-VRAM check accounts for those allocations.

Enable `DEEPCT_LEGACY_PROXY_ENABLED=true` only when the existing private ingress
rewrites legacy `POST /predict/{model_name}` to
`/assistant/legacy/predict/{model_name}` on this server. Forward new registry
`/predict/{model_id}/{version}` directly to the registry route; proxying it through
this lease would cause nested acquisition. The legacy proxy targets only
`127.0.0.1:8000/predict/{model_name}`, with a single validated name segment, and
preserves request bytes/content type/optional bearer and upstream response status,
bytes, content type and disposition. Request and response limits are 64 MiB.
Set `DEEPCT_LEGACY_INFERENCE_TOKEN` only if legacy inference already requires a
bearer; empty preserves its original unauthenticated contract. This proxy does
not expose legacy catalog, arbitrary URL or management routes.

Busy/admission rejection returns 503 with `error_code: generation_busy`;
provider timeout returns 504 with `error_code: provider_timeout`. Other provider
failures return 503 with `error_code: provider_unavailable`. Validation errors
return a safe fixed envelope without echoing messages. The synchronous worker
owns generation, lease and cleanup even after an ASGI/browser disconnect. The
request timeout defaults to 180 seconds and cleanup budget to 10 seconds via
`DEEPCT_ASSISTANT_TIMEOUT_SECONDS` and `DEEPCT_ASSISTANT_CLEANUP_SECONDS`.

Before generation the lease file records unverified residency durably. A
successful generation must unload with `/api/generate` and observe `/api/ps`
empty before clearing that marker and releasing the lease. A worker crash,
provider failure/timeout or failed unload leaves the marker intact, so all GPU
participants refuse new work across process restarts. A timeout or lost connection
can leave work pending even after a temporarily empty `/api/ps`; automatic
marker clearing in those cases would be unsafe. This favors CT safety over
availability. The application never stops another process or runs a configurable
shell hook.

To recover a poisoned lease, first stop ingress/queued GPU jobs. Acquire an
exclusive `flock` on the **existing lease file** and keep it held through recovery.
Stop only the owned `deepct-ollama-staging` user service, verify it is inactive
and that its owned runner processes have exited. Do not stop the legacy GPU
process. If the failed request was legacy inference, independently verify that
legacy inference has completed and is idle; stopping Ollama does not establish
this. For failed compatibility work, verify its owned child has exited; a killed
parent alone does not establish that. If the failed request source is unknown,
verify both runtimes are idle and any owned compatibility child has exited.
With those checks complete and the lock still held, truncate the existing
file to zero bytes and fsync it. Never unlink or replace the lease file: that
would create a second lock inode and permit overlap. Restart the owned Ollama
service, verify its `/api/ps` is empty, then resume ingress. Do not clear the
marker based solely on an unlocked file or a responding health endpoint.

CPU transport/process tests validate this protocol without claiming model quality
or GPU readiness. Staging requires separate checks of the pinned Ollama/runtime
and model integrity, real GPU residency/unload and factual/reasoning behavior.
The CT scientific acceptance and activation gate are unchanged.
