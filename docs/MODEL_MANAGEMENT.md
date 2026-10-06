# Model Management Architecture

> Status: **manual management only**. The "Sync Models" button and its
> backend (`POST /admin/models/sync`, `ModelCatalogSync`, `AdminModelService.sync`)
> have been removed. Every model row is created, edited, and deleted by hand
> from **Admin → Model Management → Add model**.

## Where models live

There is no local weights store. A row in the `models` table is a *pointer* at a
remote inference endpoint; the weights stay on the GPU host.

### Backend (Laravel)

- **Table:** `models` (migration `2026_08_13_151935_create_models_table.php`, plus
  later additions for health, worker auth, and the multi-model server fields).
- **Eloquent model:** `App\Models\Model`
  - `auth_token` is cast as `encrypted` and listed in `$hidden`, so it is
    encrypted at rest and never appears in any JSON response.
  - `has_auth_token` is the only thing the registry will say about a secret.
- **Controller:** `App\Http\Controllers\API\ModelController`
  - `index`, `store`, `show`, `update`, `destroy`, `toggleStatus`,
    `healthCheck`, `testPrediction`. There is no `sync` action any more.
- **Routes:** under `auth:sanctum` + `role:admin` in `routes/api.php`:
  - `GET    /api/admin/models`
  - `POST   /api/admin/models`
  - `GET    /api/admin/models/{id}`
  - `PUT    /api/admin/models/{id}`
  - `DELETE /api/admin/models/{id}`
  - `PATCH  /api/admin/models/{id}/toggle`
  - `POST   /api/admin/models/{id}/health-check`
  - `POST   /api/admin/models/{id}/test`

### Frontend (Flutter)

- **Service:** `fe/lib/services/admin_model_service.dart` — `AdminModelService`
  wraps the eight endpoints above. The `sync()` method and `ModelSyncResult`
  class have been removed.
- **Screen:** `fe/lib/screens/admin/model_management_screen.dart`
  - Toolbar: status filter, **REFRESH**, **ADD MODEL** (no SYNC button).
  - The model form (`_ModelFormDialog`) registers an **inference** endpoint
    (`POST /predict`). There is no longer a `kind: trainer` / "TRAINING"
    segment in the form; the field defaults to `inference` server-side.
- **Config:** `fe/lib/config/api_config.dart` — `adminModels` is the only
  model endpoint constant. `adminQueue` and `meTrainingJobs` have been removed.

## Registering a model by hand

1. Admin → Model Management → **ADD MODEL**.
2. Fill in the model name, version, and the full inference URL
   (e.g. `https://<tunnel>/predict`).
3. (Optional) shared secret — sent to the worker as `Authorization: Bearer`.
   Write-only; replacing it is the only way to change it.
4. (Optional) turn off TLS verification only for a tunnel or a self-signed
   certificate on the LAN.
5. On save, the backend runs a health check immediately and the new row's
   `status` reflects the live endpoint.

## Health and status

- `App\Services\ModelHealthChecker` probes the endpoint and writes `status`
  (`online` / `offline` / `trouble`), `last_health_check`,
  `health_check_error`, and `health_check_reason`.
- The scheduled command re-checks on a cadence; the admin can also press the
  per-card **Health check** button, which calls the same checker.

## What was removed and why

| Removed | Reason |
| --- | --- |
| `POST /api/admin/models/sync` route | Manual management replaces bulk import. |
| `ModelController::sync()` + `warmUpModel()` | Only `sync` used them. |
| `App\Services\ModelCatalogSync` | Only `sync` used it. |
| `AdminModelService.sync()` + `ModelSyncResult` | Frontend had no caller after the button was removed. |
| `services.ai_model_server.base_url` config + `AI_MODEL_SERVER_BASE_URL` | Only `sync` read it. |
| `ModelCatalogSyncTest`, `AdminQueueTest` | Tested removed behaviour. |

## Purge

Migration `2026_10_05_170847_purge_all_models` truncates the `models` table and
nullifies the foreign-key references in `analysis_records`, `training_jobs`, and
`user_activities` (`on delete set null`). It is a one-time data migration;
`down()` is intentionally a no-op.
