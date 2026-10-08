# Model management

The Next.js portal supports manual model registration and optional catalogue
synchronization. Flutter retains its existing manual management UI. The Raspberry
Pi owns the API, access control, storage and queue; inference/training workers
run remotely and are reached through the registered URLs.

Administrators can create/edit models, choose `inference` or `trainer`, configure
write-only worker credentials and TLS verification, toggle availability, check
health, and run an explicit inference test. Editing other fields preserves an
existing worker token when the token field is omitted.

`POST /api/admin/models/sync` imports the catalogue from an explicitly supplied
`base_url` or `AI_MODEL_SERVER_BASE_URL`. There is no hard-coded worker fallback.
Sync updates catalogue metadata without overwriting administrator availability
or existing secrets. Missing catalogue models become offline rather than being
deleted. Researchers see availability through `/api/me/models`, without worker
URLs or credentials.

Researcher training routes `/api/me/training/*` are available again. The web
client submits chunked dataset uploads, monitors epochs/metrics/samples, and
cancels its own runs. Administrators use `/api/admin/training/*` for oversight,
finished weights, dataset management and explicit model registration. Weights
alone do not start an inference server.

The queue board `/api/admin/queue` reports live prediction work. Prediction
positions and wait estimates still come from `QueueBoard`; the interpolation
workflow and t=0.5 recursive model contract are unchanged.

The historical `2026_10_05_170847_purge_all_models` migration remains a one-time
migration. This update adds no migration and does not purge model rows again.
