# Working on this project

> Kontrak aplikasi diperbarui 9 Oktober 2026: khusus prediksi; managed training telah dihapus.
> Status dan langkah kelanjutan agen: [checkpoint](handoff.md).

Read this before touching anything. It is short on purpose.

Read `handoff.md` first when resuming. Do not restore managed training from old
plans or historical notes: the user explicitly retired it for both roles.

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

**`octane:reload` is the third victim of the same missing function**, and it is
the one you will reach for, because reloading workers is exactly what you want
when the server is fine and only the code is stale. It dies inside
`serverIsRunning()` — before reaching the reload it was going to perform — so
you get a stack trace, an unchanged server, and no hint that the reload never
happened.

Reload the workers without going through it. `rr.exe` at the project root is
the real RoadRunner binary (`vendor/bin/rr` is a PHP installer wrapper and has
no `reset` command), and the RPC port is in the server state file:

```bash
./rr.exe reset -o version=3 -o rpc.listen=tcp://127.0.0.1:6001
```

Each worker becomes a new PHP process, so edited files are picked up. It does
not disturb a running `serve:all`, which is the difference between this and
killing the PID.

### A cached route table hides a new route completely

`npm run preserve:all` runs `php artisan route:cache`, which writes
`bootstrap/cache/routes-v7.php`. While that file exists, **`routes/api.php` is
not read at all** — by the server, by `route:list`, or by the test suite.

So a route you just added is absent everywhere, and the symptom is a plain
404 with nothing to suggest a cache is involved. `route:list` not showing it
is the giveaway: the file says one thing and the framework another.

```bash
php artisan route:clear
```

This is the twin of the Octane note above. There, `route:list` shows a route
the server has not loaded; here, the server and `route:list` agree with each
other and both disagree with the file.

### On a deployed machine, `config:cache` has already frozen `env()`

Every deploy runs `php artisan config:cache`. From that moment `config/*.php` is
a snapshot: whatever `env()` returned *at deploy time* is baked in, and the
`.env` file is no longer read at all.

The way this bites is not obvious. Run

```bash
SEED_ADMIN_PASSWORD='chosen' php artisan db:seed --force
```

and the seeder answers **"No SEED_ADMIN_PASSWORD was set, so one was
generated"** — because it asked `config('app.seed_admin_password')`, and that
was cached as `null` back when the deploy ran. The variable you just typed was
never consulted. It happened on the VPS, and the generated password is the only
one that works.

`env()` itself still resolves against the real process environment when config
is cached; it is only the *file* that stops being read. So a variable supplied
on the command line is visible to `env()` and invisible to `config()`.

`AdminUserSeeder` therefore reads `env(...) ?: config(...)`, and it is the one
place in the application allowed to call `env()` outside `config/`. The reason
is in a comment there and in `AdminSeederTest`.

**After changing `.env` on a deployed machine, run `php artisan config:cache`
again** or nothing you changed applies.

### Predictions need a queue worker

```bash
cd be && npm run serve:all      # API + queue worker + scheduler
```

Without the queue worker an upload succeeds and the job sits at `pending`
forever; without the scheduler, expired files are never deleted and model
status goes stale. Neither starts on its own, which is why `serve:all` exists.
`npm run octane:reset` handles the restart dance below.

**`--memory` does not raise PHP's memory limit.** It only decides when the
worker restarts itself. A bare `php artisan queue:work` runs at the 512 MB
default, and that used to be fatal: `TiffPreview` turned every pixel into a PHP
array entry — twice, while `unpack`'s result was copied into the accumulator —
so a 2048×2048 frame cost **196 MB**, and two of them, which `FrameMetrics`
holds at once, cost **262 MB**. The process died mid-job, took the run with it,
and the screen still said `pending` with nothing to explain it.

Pixels now live in a binary string and are unpacked a block at a time, so the
same frame costs **11.7 MB** and the pair **20 MB**. The ceiling went back up
from 2048×2048 to 4096×4096; the table of measurements and the reason it did
not go all the way back to 8192×8192 are in the constant's docblock. The limit
is now decoding *time*, not memory.

Still use `npm run queue`, which sets `-d memory_limit=1G` **and**
`--memory=768`. A frame is no longer the thing that will exhaust a worker, but
nothing else about a job got smaller.

**A stalled queue announces itself.** `QueueHealth` reports a job that has been
available for over a minute and never reserved. `message()` names the command
to type and is for administrators; `researcherMessage()` says the same fact
without a command anyone but an admin could act on. Pick by role — sending the
admin one to a researcher reads as an error they caused.

### The model worker's contract

`POST {endpoint_url}` as **multipart**: `file_t0`, `file_t2`, `time_scalar`.
It streams a TIFF back. A *handled* failure comes back as JSON `{"error": ...}`
with **HTTP 200**, so the status code alone cannot tell you whether it worked.

Interpolation is always t=0.5 and recursive: for frames 1 and 7, generate 4
first, then use it as a boundary for 1-4 and 4-7. There is no manual
`time_scalar` input anywhere in the product.

**That is not a UI simplification — the model cannot do anything else.**
Measured 4 September 2026: moving `time_scalar` from 0 to 1 shifts the output by
**0.17%** of the distance between the two boundary frames. Asking for t=0.25
returns the midpoint. Do not add a `time_scalar` control expecting it to work,
and do not read a repo comment claiming the model "ignores" t either — it
responds, just far too weakly to use.

**Error compounds 1.73× per synthetic boundary**, so recursion has a depth
budget. Holding the span constant: 359.7 MAE between two scanned frames, 623.6
against a generated boundary, 1,174.9 two levels deep — past the 555 you get by
copying the neighbouring scanned frame outright. Only frames whose two
boundaries were both scanned are worth trusting: gap 2 gives 1 of 1, gap 4
gives 1 of 3, gap 8 gives **0 of 7**. The `generation` field on each frame is
how you tell which is which.

**MAE and PSNR will mislead you here.** Linear blending — averaging the two
boundary frames — beats the model on MAE (4 of 5 cases) and PSNR (5 of 5),
because the average is the guess that minimises squared error. On **SSIM** the
model wins **5 of 5**, and its margin widens on the harder cases. A blurry
projection frame wrecks reconstruction, so never use MAE or PSNR alone as the
success measure.

**A shared secret needs both halves, and half of it lives on Kaggle.** The
platform sends the model's `auth_token` as `Authorization: Bearer`; the worker
only checks it if `WORKER_TOKEN` is set in its environment — read from Kaggle
Secrets, never pasted into the script. Empty means open, which is the default,
so setting the token in **Admin → Model Management** alone changes nothing
until the Kaggle session is restarted with the secret. The inference script prints which authentication mode it uses at startup.

### Flutter gotchas

- **`file_picker` is pinned to `^11.0.0` and both bounds matter.** 6.x and 8.x
  still reference the removed v1 embedding and break `flutter build apk` at Java
  compilation; 12.x needs `win32 ^6.3.0` against `flutter_secure_storage` 9.x's
  `win32 ^5.0.0`. Read the comment in `pubspec.yaml` before changing it.
- **Never ask `file_picker` for `FileType.custom`.** The extension list means
  three different things: an extension filter in a desktop browser's OS dialog
  (works), intent type `*/*` on Android native (never filtered at all), and
  `accept=" .zip"` on mobile web — which Chrome must translate to MIME types,
  and Android reports a ZIP as `application/octet-stream` as often as
  `application/zip`, so the file greys out and **cannot be selected**. Ask for
  `FileType.any` (or `FileType.image`, a MIME filter that is portable) and
  check the name yourself with `hasExtension` in `lib/utils/file_extension.dart`.
  Testing an upload only on desktop web and the APK will not catch this.
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
- Flutter keeps its square visual theme. Web inputs/buttons now use rounded
  corners, comfortable spacing and focus/hover feedback per the user request.
  Use `withValues(alpha:)` rather than the deprecated Flutter `withOpacity`.

### Under Octane, `upload_max_filesize` does not apply — but `post_max_size` does

RoadRunner parses the multipart body itself, so `upload_max_filesize` never gets
a say: a 4 MB upload succeeds against a 2 MB limit.

**`post_max_size` is a different story, and the sentence that used to sit here
said it was not.** Laravel's own `ValidatePostSize` middleware reads
`ini_get('post_max_size')` and compares it to `CONTENT_LENGTH`, so the limit is
enforced by the framework long before RoadRunner's `max_request_size` is
reached. It was left at the stock **8M** on this machine, and the symptoms did
not look like a size limit at all:

- a 19 MB dataset posted whole answered **"The POST data is too large"**, while
  the same archive sent through the chunked endpoint went up without complaint,
  because each chunk is small.

`post_max_size` is now 256M, and `upload_max_filesize` matches it so the two
cannot disagree. **Restart Octane after changing either** — `php.ini` is read
once per process, and the running workers keep the old value.

`.rr.yaml` is empty and that is not a mistake: Octane passes RoadRunner its
settings as `-o` flags, so there is nothing to find in that file.

All of this changes again if the app is ever deployed behind nginx + PHP-FPM,
where `client_max_body_size` becomes a third ceiling.

### Mojibake spreads through ordinary editing, and nothing warns you

The admin dashboard shipped `by Administrator â€¢ 4d ago`. Not a rendering
fault — that byte sequence was **in the source file**. A UTF-8 file had been
read back as Windows-1252 and saved again, turning `•` (E2 80 A2) into three
characters. Eight files were affected, and one line in `prediction.dart` had
been through it **three times** (`ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â`). Five of them were text a
user reads.

It is invisible in review: the file still parses, the tests still pass, and the
only symptom is a glyph nobody looks at twice. So there are tripwires —
`fe/test/source_encoding_test.dart` scans `lib/` and `test/`,
`be/tests/Unit/SourceEncodingTest.php` scans `app/`, `routes/`, `config/`,
`database/` and `tests/`. Both reject five mojibake patterns. **If one goes
red, fix the file, do not relax the test.**

Two things to know if you ever have to repair it by hand. Decoding once is not
enough — loop until the result stops changing. And cp1252 has five undefined
slots (`0x81`, `0x8D`, `0x8F`, `0x90`, `0x9D`); map each to its own byte value
or seven lines will refuse to come back, which is exactly what happened here.

The PHP guard extends PHPUnit's `TestCase`, not Laravel's, so it uses
`dirname(__DIR__, 2)` rather than `base_path()`.

## Verify your work

```bash
cd be && php artisan test          # 329 tests locally verified on 9 October 2026; db_aict_test required
cd fe && flutter analyze           # must be clean
cd fe && flutter test              # 276 tests
cd fe && flutter build apk --release
```

Writing a backend test? Two traps, both documented in `be/README.md`: use
`$this->apiAs($token)` rather than setting the Authorization header yourself,
and call `Storage::fake('local')` if the test touches files.

For anything touching the prediction pipeline, run it end to end against the
real worker. A passing build says nothing about whether interpolation works.

## Credentials (development)

Nothing is hard-coded. `php artisan db:seed` creates the first administrator
from `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD`; leave the password unset and
the seeder generates one and prints it once.

New accounts created by an administrator get the default in
`UserController::DEFAULT_PASSWORD` and **cannot reach the console** until they
replace it — `PasswordGate` stands in the way. An admin password reset re-arms
that.

**Concurrent sessions are allowed.** Each login mints its own token and leaves
existing ones alone, so the same account can be signed in on a laptop and a
phone at once, and a script logging in does not disturb anyone. Tokens expire
after 7 days (`config/sanctum.php`); `tokens:cleanup` sweeps the expired rows.

Logging out revokes only the token that made the request.
