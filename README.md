# Neutron CT Frame Interpolation Platform

A research platform for **Badan Riset dan Inovasi Nasional (BRIN)** that fills
gaps in Neutron CT frame sequences using deep learning.

A researcher uploads an archive of numbered `.tif` frames with gaps in the
numbering. The platform generates the missing frames by recursive interpolation
and returns the completed sequence.

```
frame_001.tif  frame_005.tif          frame_001 … 002 003 004 … frame_005
      │              │          ──►         (three frames generated)
      └── uploaded ──┘
```

---

## Architecture

```
Flutter (Android + iOS)       Next.js (website + admin/user portal)
             └──────────── HTTPS ────────────┘
                              ▼
Laravel 12 + Octane/RoadRunner  ──►  MySQL 8
          │
          │  HTTPS
          ▼
FastAPI inference worker (GPU, .h5 weights)
```

Heavy computation is deliberately separated: the platform owns storage,
orchestration and access control; inference runs on a GPU host reached over
HTTPS. The platform never loads model weights itself.

**Interpolation is recursive at t=0.5.** For frames 1 and 7 the midpoint 4 is
generated first, then used as a boundary for 1–4 and 4–7. Recursion is not a
refinement here — it is the only way this model can be driven. Measured on
4 September 2026 against real BRIN archives: moving `time_scalar` from 0 to 1
shifts the output by **0.17%** of the distance between the two boundary frames,
so asking for any point other than the midpoint returns the midpoint anyway.

**That carries a limit worth knowing before reading any output.** Error
compounds **1.73× per synthetic boundary**. Holding the span constant, a frame
drawn between two scanned frames measures MAE 359.7; one drawn against a
generated boundary, 623.6; one two levels deep, 1,174.9 — past the 555 you get
by simply copying the neighbouring scanned frame. So **only frames whose two
boundaries were both scanned are reliable**: a gap of 2 yields 1 of 1, a gap of
4 yields 1 of 3, a gap of 8 yields **0 of 7**.

The platform still fills wide gaps, and every frame carries how it was derived
in `generation`, so the archive says which is which. The measurements are in
[CHANGELOG.md](CHANGELOG.md) 1.39.0; the model journal is
[AI_EXPERIMENTS.md](AI_EXPERIMENTS.md).

Full component and schema documentation: **[ARCHITECTURE.md](ARCHITECTURE.md)**.

---

## Capabilities

| Area | What it does |
|---|---|
| **Prediction pipeline** | ZIP upload → validation → frame preview → explicit start → queued job → recursive interpolation → checksum-verified download |
| **Frame provenance** | Every generated frame records the two frames it was drawn between and its generation — 1 when both boundaries were scanned, higher when the model was fed its own output. Travels in the archive's `metadata.json` and `manifest.csv` |
| **Hold-out validation** | Where the archive holds three consecutive frames, the middle one is set aside, regenerated, and measured against the real one: MAE, RMSE and PSNR, with the reference frame's own range so the numbers can be read |
| **Model comparison** | The same frames re-run through another registered model, with each run's error side by side. Inputs are copied, so either run can be deleted without stranding the other |
| **Evidence after expiry** | Six thumbnails per run kept permanently, outside the folder retention deletes — a completed job stays something you can look at, not just a row |
| **Resumable upload** | Chunked, resumable on both sides; server-computed chunk size; an interrupted upload is offered back on the device. Native clients read ZIPs a range at a time; browser and loose-frame bundling still hold source bytes in memory |
| **Frame preview** | 16-bit TIFF rendered to PNG server-side, in pure PHP — no imaging extension required |
| **Retention** | Results deleted 24 hours after generation; the record and its audit trail remain |
| **Dataset retention** | Training archives nobody has come back to are freed on a window measured from **last use**, not upload — a dataset is uploaded here precisely to be reused. One with a queued or running job is never swept. The run's numbers stay; the frames behind them go, and the API says which of the two an empty frame list means |
| **Storage guard** | Prediction upload and direct training upload refuse with 507 when there is no room. ZIP extraction checks expanded size, frame count, duplicate names and available space before writing. A sentinel file proves the results volume is mounted |
| **Storage report** | Free space on the admin dashboard, split into what retention reclaims within a day and what nothing reclaims at all |
| **Model registry** | One FastAPI/ngrok server can publish many models through `/models`; admin sync upserts them by slug and each row keeps its own `/predict/{model}` path. Availability is checked every minute and on demand |
| **Queue board** | Who the model is working for right now and who is waiting behind them, in the worker's own order — read from the prediction records rather than inferred from the audit trail, and numbered by the same definition the researcher sees on their own job |
| **Worker credentials** | A per-model shared secret sent as `Authorization: Bearer` and checked by the worker in constant time, stored encrypted and write-only through the API, plus a per-model say over TLS verification — needed the moment a worker moves off a random tunnel onto a LAN address |
| **Managed training** | Datasets, a job queue, and a GPU worker protocol that survives the worker dying mid-run |
| **Access control** | Admin-created accounts, no self-registration, server-enforced replacement of issued passwords; disabling or resetting an account revokes its tokens |
| **Messaging** | In-app conversations with administrators, plus a public channel for people who cannot sign in |
| **Research news** | Admin-published posts with photos, shown as a slideshow on the landing page |
| **Audit trail** | Every state-changing action recorded, filterable, exportable to CSV |

---

## Requirements

| | Version |
|---|---|
| PHP | 8.2+ |
| MySQL | 8.0+ |
| Flutter | 3.44+ |
| Node.js | 22+ (Next.js 16 and Octane tooling) |

---

## Running it locally

### Backend

```bash
cd be
composer install && npm install
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
npm run serve:all
```

`serve:all` starts **three processes**, and all three are required:

| Process | Without it |
|---|---|
| Octane (API) | No API at all |
| `queue:work` | Upload and preview work, but jobs stay `pending` after START |
| `schedule:work` | Expired files are never deleted; model status goes stale |

The seeder creates the first administrator. Set `SEED_ADMIN_PASSWORD` in `.env`
beforehand, or it generates one and prints it once.

### Flutter client

```bash
cd fe
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

The API address is a build-time constant, so every target is selected with
`--dart-define` rather than by editing a file. See [fe/README.md](fe/README.md).

### Next.js website

```bash
cd fe_web
cp .env.example .env.local
npm ci
npm run dev
```

Set `LARAVEL_API_BASE_URL=http://127.0.0.1:8000/api`. Laravel remains the only
backend and authorization authority; Next.js keeps its Sanctum token in an
`HttpOnly` cookie and presents a same-origin BFF to the browser. See
[fe_web/README.md](fe_web/README.md).

### Inference worker

The worker is a FastAPI application holding the `.h5`/`.keras` weights, running
on a GPU host and exposed over HTTPS. `AI_MODEL_SERVER_BASE_URL` selects the
server (currently `https://nucleus-drone-grueling.ngrok-free.dev`); **Admin →
Model Management → Sync Models** imports every row from `GET /models`.

One tunnel serves every model. The catalogue supplies paths such as
`/predict/ginet-tcd-revisi`; Laravel posts multipart `file_t0`, `file_t2` and
`time_scalar` to the selected model's full URL and requires `image/tiff` on
success. Legacy workers may return a handled JSON error with HTTP 200, so the
body type is still checked.

---

## Testing

```bash
cd be && php artisan test        # 396 tests, 1,593 assertions (8 October 2026 local validation)
cd fe && flutter analyze         # must be clean
cd fe && flutter test            # 276 tests across 33 files
cd fe_web && npm run check       # ESLint + TypeScript
cd fe_web && npm test            # same-origin proxy regression checks
cd fe_web && npm run build       # production Next.js build
```

The backend suite runs against MySQL rather than SQLite: several migrations use
`ALTER TABLE … MODIFY`, so a SQLite run would produce both false passes and
false failures. Create `db_aict_test` once.

The GPU worker is faked in tests. A real inference call costs ~20 seconds and
GPU quota, and what is worth testing here is the orchestration, not the model.

---

## Building for release

```bash
cd fe
flutter build web --release   --dart-define=API_BASE_URL=https://api.example.org/api
flutter build apk --release   --dart-define=API_BASE_URL=https://api.example.org/api
flutter build ipa --release   --dart-define=API_BASE_URL=https://api.example.org/api   # macOS only
```

Pushing a `v*` tag runs all three in CI and publishes the artifacts — see
[.github/workflows/release.yml](.github/workflows/release.yml).

---

## Deployment

The existing Flutter web client is a static bundle. The new `fe_web` client is
a Next.js application with server-side Route Handlers, deployed as a separate
Vercel project. Flutter remains the mobile client; both clients use the same
Laravel API and database.

**The backend requires a persistent server**, not a serverless platform. Octane
is a long-lived process, the queue worker and scheduler are long-lived
processes, the health check runs on a one-minute interval, a prediction job may
run for up to two hours, and results reach ~1.5 GB on disk. Production has been
moved from the VPS to a Raspberry Pi 5 with nginx, PM2 and RoadRunner; the
public API is exposed by an ngrok HTTPS tunnel on port 8000. The Flutter web bundle is
built by GitHub Actions and sent to Vercel as prebuilt output, so Vercel never
runs Laravel.

**Migration state observed on 1 October 2026:** the backend is installed at
`/var/www/deepct-ai` on the Pi. PHP 8.2, MariaDB 10.11, nginx and ARM64
RoadRunner are installed. PM2 keeps `deepct-app` (`npm run serve:all`) and
`deepct-ngrok` online, and the enabled `pm2-jihyo.service` restores both after a
reboot. Every migration reports `Ran`; `/api/health` and the database-backed
`/api/news` both answer 200 locally and at
`https://zestfully-usable-pledge.ngrok-free.dev`. The `deepct-raspi`
self-hosted GitHub runner is online and the production deployment from commit
`c6f4f1f` completed successfully. A manual, secret-backed bootstrap created and
verified both administrator and researcher accounts; production login, role
separation, logout and token revocation passed 12 of 12 black-box checks. The
Flutter site is live at `https://deep-ct-ai-prod.vercel.app`. The separate
Next.js project is live at `https://deepct-web.vercel.app` with Vercel Root
Directory `fe_web`; it is not a replacement for the Laravel backend. Its first
bootstrap deployment came from `develop` because Vercel assigns a new
project's first deployment to production automatically. Subsequent `develop`
deployments are previews, and the workflow passes `--prod` only for `main`.

**Portal deployment observed on 8 October 2026:** commit `998df0f` on `main`
passed Next.js verification and deployed to `https://deepct-web.vercel.app`.
The Raspberry Pi deploy backed up its database, refreshed caches and restarted
the API; all 30 authenticated/public endpoint and role smoke checks passed.
Another 20 public HTTP checks passed against the deployed web and API, including
the full research article, request/reset pages, proxy-origin checks and anonymous
portal guards. Local validation passed 396 Laravel tests/1,593 assertions and
48 browser checks. The portal now exposes admin/user operations, training,
application disk cleanup and signed artifact downloads. Laptop synchronization
is still blocked: this executor has no configured VPN or TCP grant, and SSH to
`100.85.5.67:22` cannot connect. Live GPU prediction/training acceptance remains
an outstanding research validation step.

The application cutover is complete, but the old VPS's historical database and
`storage/` contents have **not** been copied. At the 1 October cutover the production
model catalogue was empty. A real prediction against the GPU worker has not yet
been accepted on the new deployment. Those are explicit follow-up items, not hidden
inside the word “migrated”.

The release workflow now targets a self-hosted ARM64 runner labelled
`deepct-raspi`; the Pi is private behind NetBird, so a GitHub-hosted runner
cannot SSH into it. `RASPI_API_BASE_URL` is the one build-time API address and
has no fallback to the retired VPS. The Flutter deployment keeps its current
Vercel project ID. Next.js requires a separate
`DEEPCT_WEB_VERCEL_PROJECT_ID`; the token and organization may be shared
because both projects can belong to the same Vercel account.

The one-time provisioning script retains its historical filename,
[`be/scripts/provision-vps.sh`](be/scripts/provision-vps.sh), but now also
bootstraps a fresh Pi correctly: Composer runs before the first Artisan command,
`.env` is mode 600, production caches are generated, and the RoadRunner binary
is downloaded for the host architecture.

Configuration, tunnel layout, the PM2 process file and the deploy job step by
step are in [ARCHITECTURE.md](ARCHITECTURE.md) §8, along with the
pre-deployment checklist.

---

## Documentation

| File | Contents |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Components, data flow, database schema, technical decisions, deployment |
| [API.md](API.md) | Complete endpoint reference (105 endpoints) |
| [be/README.md](be/README.md) | Backend setup, operations, troubleshooting |
| [fe/README.md](fe/README.md) | Frontend structure, breakpoints, platform notes |
| [fe_web/README.md](fe_web/README.md) | Next.js website, BFF/auth boundary, development and deployment |
| [ROADMAP.md](ROADMAP.md) | Planned work, and what was deliberately not built |
| [CHANGELOG.md](CHANGELOG.md) | What changed and why |
| [CLAUDE.md](CLAUDE.md) | Working agreements, and the traps that cost time here |
| [WHITE_BOX_TESTING.md](WHITE_BOX_TESTING.md) | Repeatable unit, integration and build scenarios with observed CI results |
| [USER_ACCEPTANCE_TESTING.md](USER_ACCEPTANCE_TESTING.md) | Production black-box and user acceptance scenarios with observed results |
| [PRD.md](PRD.md) · [DESIGN.md](DESIGN.md) · [AI_EXPERIMENTS.md](AI_EXPERIMENTS.md) | Product intent, visual system, model research journal |

---

## Security notes

- Authentication uses Sanctum bearer tokens with a 7-day expiry. Concurrent
  sessions are permitted; signing out revokes only the token that made the
  request.
- There is no self-registration. Accounts are created by an administrator or by
  approving a request from the landing page, and an account issued a default
  password cannot reach the console until it sets its own.
- No credentials are stored in this repository. The seeded administrator
  password, the inference endpoint and the training worker token all come from
  the environment.
- Model endpoint URLs are visible to administrators only: knowing one would
  allow bypassing the platform and calling the GPU worker directly.

---

**Institution:** Badan Riset dan Inovasi Nasional (BRIN)
