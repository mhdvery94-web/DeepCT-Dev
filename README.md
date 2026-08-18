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
Flutter (web + Android + iOS)
          │  HTTPS
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
generated first, then used as a boundary for 1–4 and 4–7. The model was trained
on a t-imbalanced dataset, and recursion is how the platform works around that
bias — see [AI_EXPERIMENTS.md](AI_EXPERIMENTS.md).

Full component and schema documentation: **[ARCHITECTURE.md](ARCHITECTURE.md)**.

---

## Capabilities

| Area | What it does |
|---|---|
| **Prediction pipeline** | ZIP upload → validation → queued job → recursive interpolation → checksum-verified download |
| **Resumable upload** | Chunked, resumable on both sides; server-computed chunk size; an interrupted upload is offered back on the device |
| **Frame preview** | 16-bit TIFF rendered to PNG server-side, in pure PHP — no imaging extension required |
| **Retention** | Results deleted 24 hours after generation; the record and its audit trail remain |
| **Model registry** | Multiple inference endpoints, health-checked every minute and on demand from the upload screen, with live availability in both consoles |
| **Managed training** | Datasets, a job queue, and a GPU worker protocol that survives the worker dying mid-run |
| **Access control** | Admin-created accounts, no self-registration, forced replacement of issued passwords |
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
| Node.js | 18+ (Octane tooling only) |

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
| `queue:work` | Uploads succeed but predictions stay `pending` forever |
| `schedule:work` | Expired files are never deleted; model status goes stale |

The seeder creates the first administrator. Set `SEED_ADMIN_PASSWORD` in `.env`
beforehand, or it generates one and prints it once.

### Frontend

```bash
cd fe
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

The API address is a build-time constant, so every target is selected with
`--dart-define` rather than by editing a file. See [fe/README.md](fe/README.md).

### Inference worker

The worker is a FastAPI application holding the `.h5` weights, running on a GPU
host and exposed over HTTPS. Register its URL through **Admin → Model
Management**; it is not configured through `.env`.

Its contract is a multipart `POST` with `file_t0`, `file_t2` and `time_scalar`,
returning a TIFF. A *handled* failure comes back as JSON with **HTTP 200**, so
the status code alone never confirms success.

---

## Testing

```bash
cd be && php artisan test        # 238 tests
cd fe && flutter analyze         # must be clean
cd fe && flutter test            # 129 tests
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

The web client is a static bundle and deploys to any static host or CDN.

**The backend requires a persistent server**, not a serverless platform. Octane
is a long-lived process, the queue worker and scheduler are long-lived
processes, the health check runs on a 10-second interval, a prediction job may
run for up to two hours, and results reach ~1.5 GB on disk. A small VPS with
nginx, supervisor and MySQL covers all of it.

Pushing to `main` deploys both halves: the web client to Vercel, and the
backend to the VPS over SSH — rsync, `composer install --no-dev`, a database
dump, `migrate --force`, and a supervisor restart, followed by a request to the
running process to confirm it came back. It needs the repository secrets
`VPS_HOST`, `VPS_USERNAME`, `VPS_SSH` and optionally `VPS_PORT`.

The server is prepared once, by hand, with
[`scripts/provision-vps.sh`](scripts/provision-vps.sh) — database, `.env`,
RoadRunner, supervisor and nginx. The deploy job never writes any of them,
because a deploy that owned them would overwrite production credentials on the
next push.

**There are two backends now, and a client can only point at one.** The lab
machine behind ngrok and the VPS are both valid; the API address is compiled
into every build, and the repository variable `NGROK_BE` decides which one a
build talks to.

Configuration, DNS layout, the supervisor unit files and the deploy job step by
step are in [ARCHITECTURE.md](ARCHITECTURE.md) §8, along with the
pre-deployment checklist.

---

## Documentation

| File | Contents |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Components, data flow, database schema, technical decisions, deployment |
| [API.md](API.md) | Complete endpoint reference (89 endpoints) |
| [be/README.md](be/README.md) | Backend setup, operations, troubleshooting |
| [fe/README.md](fe/README.md) | Frontend structure, breakpoints, platform notes |
| [ROADMAP.md](ROADMAP.md) | Planned work, and what was deliberately not built |
| [CHANGELOG.md](CHANGELOG.md) | What changed and why |
| [CLAUDE.md](CLAUDE.md) | Working agreements, and the traps that cost time here |
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
