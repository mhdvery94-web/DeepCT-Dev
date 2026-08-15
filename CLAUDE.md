# Working on this project

Read this before touching anything. It is short on purpose.

## What this is

A BRIN research platform for **Neutron CT frame interpolation**. A researcher
uploads a ZIP of numbered `.tif` frames with gaps in the numbering; the platform
fills those gaps by calling a deep-learning model, and hands back a ZIP.

Three moving parts, and they are genuinely separate machines:

| Part | Where | What it is |
|------|-------|-----------|
| `be/` | this machine, port 8000 | Laravel 12 + Octane/RoadRunner API |
| `fe/` | web + Android | Flutter client |
| model worker | **Kaggle/Colab**, behind ngrok | FastAPI app holding the `.h5` weights |

The model worker is not ours and is not always up. Its Kaggle session expires on
its own.

## The documents

| File | Read it when |
|------|--------------|
| [README.md](README.md) | Always. What works today and how to run it. |
| [ROADMAP.md](ROADMAP.md) | Before starting anything. What is planned, in order, and what was deliberately not done. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Changing how components talk, or the schema. |
| [API.md](API.md) | Touching any endpoint. |
| [be/README.md](be/README.md) / [fe/README.md](fe/README.md) | Working inside that half. |

`PRD.md`, `DESIGN.md` and `AI_EXPERIMENTS.md` are background: product intent, the
visual system, and the model research journal. Read them when the work is about
those things, not otherwise.

`CHANGELOG.md` is the record of what changed and *why*. Add to it.

## Rules

**1. Verify before you claim.** Run the command, read the output, then write the
status. This project once carried a document titled "COMPLETE & PRODUCTION
READY" describing code that did not compile — the author had started
`flutter analyze` and never read the result. Every status line in these docs
should be something someone actually observed.

**2. `route:list` is not proof the server has the route.** See the Octane note
below. Neither is "I added the file".

**3. Do not add a status document.** No `*_COMPLETION_SUMMARY.md`,
no `*_PLAN.md`, no `TASK_*.md`. Twenty of those accumulated here and contradicted
each other.

Planned work goes in [ROADMAP.md](ROADMAP.md) — one living list, ticked only
after verification. Finished work goes in `CHANGELOG.md`. Current state goes in
`README.md`. Those three cover every case; a new file does not.

**4. Say what you did not do.** A half-finished thing that is labelled
half-finished is fine. A half-finished thing labelled done costs someone a day.

## Things that will waste your time if you do not know them

### Octane cannot restart itself on Windows

`octane:start` and `octane:stop` both call `posix_kill()`, which does not exist
on Windows. They crash *before doing anything*, leaving the old process running,
so a new route keeps 404ing no matter how many times you "restart".

```bash
netstat -ano | findstr :8000
taskkill /PID <PID> /F
rm storage/logs/octane-server-state.json   # or the next start crashes too
npm run octane
```

Confirm you are on a new process by comparing its start time to the file you
edited. `php artisan route:list` runs in its own short-lived process and will
happily show a route the running server has never loaded.

### Predictions need a queue worker

```bash
cd be && npm run serve:all      # API + queue worker + scheduler
```

Without the queue worker an upload succeeds and the job sits at `pending`
forever; without the scheduler, expired files are never deleted and model
status goes stale. Neither starts on its own, which is why `serve:all` exists.
`npm run octane:reset` handles the restart dance below.

### The model worker's contract

`POST {endpoint_url}` as **multipart**: `file_t0`, `file_t2`, `time_scalar`.
It streams a TIFF back. A *handled* failure comes back as JSON `{"error": ...}`
with **HTTP 200**, so the status code alone cannot tell you whether it worked.

Interpolation is always t=0.5 and recursive: for frames 1 and 7, generate 4
first, then use it as a boundary for 1-4 and 4-7. There is no manual
`time_scalar` input anywhere in the product.

### Flutter gotchas

- **`file_picker` is pinned to `^11.0.0` and both bounds matter.** 6.x and 8.x
  still reference the removed v1 embedding and break `flutter build apk` at Java
  compilation; 12.x needs `win32 ^6.3.0` against `flutter_secure_storage` 9.x's
  `win32 ^5.0.0`. Read the comment in `pubspec.yaml` before changing it.
- **A screen without an `AppBar` needs `SafeArea`.** Scaffold only applies the
  status-bar inset when an `AppBar` is present, otherwise content renders under
  the clock and battery.
- **Never import `dart:html`.** It breaks the Android build at kernel
  compilation even if the code path never runs. Use the conditional export in
  `lib/utils/file_download.dart`.
- **`DropdownButtonFormField` needs `isExpanded: true`** inside any constrained
  row or column. Without it the dropdown sizes to its longest *option* rather
  than the space it was given, and overflows on a phone — this cost 54px in
  `PublicTicketSheet` before a layout test caught it.
- Square corners everywhere (`BorderRadius.zero`), and `withValues(alpha:)`
  rather than the deprecated `withOpacity`.

### Under Octane, `php.ini` upload limits mostly do not apply

RoadRunner parses the multipart body itself, so `upload_max_filesize` never gets
a say — a 4 MB upload succeeds against a 2 MB limit. The real ceiling is
RoadRunner's `max_request_size`. This changes if the app is ever deployed behind
nginx + PHP-FPM.

## Verify your work

```bash
cd be && php artisan test          # 156 tests, needs the db_aict_test database
cd fe && flutter analyze           # must be clean
cd fe && flutter test              # 54 tests
cd fe && flutter build apk --release
```

Writing a backend test? Two traps, both documented in `be/README.md`: use
`$this->apiAs($token)` rather than setting the Authorization header yourself,
and call `Storage::fake('local')` if the test touches files.

For anything touching the prediction pipeline, run it end to end against the
real worker. A passing build says nothing about whether interpolation works.

## Credentials (development)

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@brin.go.id | admin123 |
| Researcher | researcher@brin.go.id | user123 |

New users get `BrinResearch2026`.

**Concurrent sessions are allowed.** Each login mints its own token and leaves
existing ones alone, so the same account can be signed in on a laptop and a
phone at once, and a script logging in does not disturb anyone. Tokens expire
after 7 days (`config/sanctum.php`); `tokens:cleanup` sweeps the expired rows.

Logging out revokes only the token that made the request.
