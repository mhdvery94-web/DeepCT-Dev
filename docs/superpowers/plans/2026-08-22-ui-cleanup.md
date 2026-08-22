# Bagian A — Bersih-bersih UI: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membuat teks bisa disalin, memberi daftar aktivitas area scroll sendiri, memperlakukan model berstatus `trouble` sebagai tersedia alih-alih tampak mati, dan mengganti jargon `ERR_NGROK_3200` dengan kalimat yang bisa ditindaklanjuti bagi periset — dengan diagnostik mentahnya tetap utuh untuk admin.

**Architecture:** `ModelHealthChecker` menulis satu kode alasan (`no_endpoint`, `tunnel_down`, `unreachable`, `slow`) ke kolom baru di samping pesan mentah yang sudah ada. Klien memetakan kode itu ke kalimat lewat satu fungsi bersama, sehingga strip status, layar unggah, dan layar admin memakai kata yang sama. Perubahan UI sisanya murni tata letak dan tidak menyentuh jaringan.

**Tech Stack:** Laravel 12 + Octane/RoadRunner (backend), Flutter (frontend), MySQL.

## Global Constraints

- **Bahasa antarmuka tetap Inggris**, termasuk pesan kegagalan. Yang dibuang adalah jargonnya, bukan bahasanya. Balasan ke pengguna dalam percakapan tetap Indonesia; teks di dalam kode Inggris.
- **Sudut kotak di mana-mana** (`BorderRadius.zero`), dan `withValues(alpha:)` bukan `withOpacity` yang usang.
- **Jangan tambah dokumen status.** Tidak ada `*_COMPLETION_SUMMARY.md`, `*_PLAN.md`, atau `TASK_*.md`. Hasil dicatat di `CHANGELOG.md`, centang di `ROADMAP.md` §12 hanya setelah diverifikasi.
- **Warna hanya dari `AppTheme`**: `success`/`successLight` (#059669/#D1FAE5), `warning`/`warningLight` (#F59E0B/#FEF3C7), `error`/`errorLight` (#DC2626/#FEE2E2), `textMuted` (#64748B).
- **Tidak ada paket Flutter baru di bagian A.** `pubspec.yaml` tidak disentuh sama sekali.
- **Octane tidak bisa restart sendiri di Windows.** Setelah mengubah PHP, jalankan `npm run octane:reset` di `be/`; `php artisan route:list` berjalan di proses lain dan bukan bukti server sudah memuat perubahan.
- **Test backend butuh basis data `db_aict_test`.** `Storage::fake('local')` bila test menyentuh berkas, dan `$this->apiAs($token)` bukan `withHeader('Authorization', …)` — lihat `be/tests/TestCase.php`.
- Verifikasi penuh: `cd be && php artisan test` (242 test), `cd fe && flutter analyze` (harus bersih), `cd fe && flutter test` (129 test), `cd fe && flutter build apk --release`.

---

### Task 1: Kode alasan di ModelHealthChecker

**Files:**
- Create: `be/database/migrations/2026_08_22_090001_add_health_check_reason_to_models_table.php`
- Modify: `be/app/Models/Model.php:9-29` (daftar `$fillable`)
- Modify: `be/app/Services/ModelHealthChecker.php` — tanda tangan `persist()` di baris 243-248 dan delapan pemanggilnya
- Test: `be/tests/Feature/ModelHealthCheckTest.php` (baru)

**Interfaces:**
- Consumes: tidak ada, task pertama.
- Produces: kolom `models.health_check_reason` bertipe `string(20)` nullable, berisi salah satu dari `'no_endpoint'`, `'tunnel_down'`, `'unreachable'`, `'slow'`, atau `null` saat `online`. Konstanta `ModelHealthChecker::REASON_NO_ENDPOINT`, `REASON_TUNNEL_DOWN`, `REASON_UNREACHABLE`, `REASON_SLOW`.

- [ ] **Step 1: Tulis migrasinya**

Berkas `be/database/migrations/2026_08_22_090001_add_health_check_reason_to_models_table.php`:

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A machine-readable reason beside the human-readable one.
 *
 * `health_check_error` holds the checker's own words — "Tunnel is not running
 * (ERR_NGROK_3200)", "Endpoint unreachable (HTTP 502)". Those are the right
 * words for the administrator who has to go and restart the Kaggle session,
 * and the wrong words for a researcher who only wants to know whether they can
 * upload. The client cannot tell one failure from another by parsing that
 * string, so it cannot say anything better than the string itself.
 *
 * This column lets it. The raw message stays exactly as it was and stays on
 * the admin screen; everyone else reads a sentence chosen from this code.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->string('health_check_reason', 20)
                ->nullable()
                ->after('health_check_error');
        });
    }

    public function down(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->dropColumn('health_check_reason');
        });
    }
};
```

Tidak ada backfill. Baris yang sudah ada bernilai `null` sampai pemeriksaan kesehatan berikutnya menulisinya — paling lama satu menit, karena penjadwal berjalan tiap menit, dan sisi klien sudah menangani `null` (Task 3).

- [ ] **Step 2: Jalankan migrasinya**

Run: `cd be && php artisan migrate`
Expected: `2026_08_22_090001_add_health_check_reason_to_models_table ... DONE`

- [ ] **Step 3: Tambahkan kolom ke `$fillable`**

Di `be/app/Models/Model.php`, di dalam array `$fillable`, tepat setelah baris `'health_check_error',`:

```php
        'health_check_error',
        'health_check_reason',
```

Tanpa ini `Model::create([... 'health_check_reason' => 'slow'])` di test Task 2 diam-diam membuang nilainya dan test gagal dengan cara yang membingungkan.

- [ ] **Step 4: Tulis test yang gagal**

Berkas baru `be/tests/Feature/ModelHealthCheckTest.php`:

```php
<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Services\ModelHealthChecker;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * What the health checker writes down about a failure.
 *
 * Two columns, two audiences. `health_check_error` keeps the checker's own
 * words for the administrator who has to act on them; `health_check_reason`
 * is the code the client turns into a sentence a researcher can read.
 */
class ModelHealthCheckTest extends TestCase
{
    use RefreshDatabase;

    private function model(array $overrides = []): Model
    {
        return Model::create(array_merge([
            'name' => 'deepCT TC-D',
            'version' => 'v1',
            'kind' => 'inference',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'offline',
            'is_active' => true,
            'max_concurrent_jobs' => 1,
        ], $overrides));
    }

    public function test_a_model_without_an_endpoint_is_not_a_dead_server(): void
    {
        $model = $this->model(['endpoint_url' => null]);

        (new ModelHealthChecker())->check($model);

        $model->refresh();
        $this->assertSame('offline', $model->status);
        // Not `unreachable`: nothing was ever configured to reach. Telling
        // someone to restart a server that was never registered is the wrong
        // instruction.
        $this->assertSame('no_endpoint', $model->health_check_reason);
    }

    public function test_an_ngrok_error_header_is_recorded_as_a_dead_tunnel(): void
    {
        Http::fake([
            '*' => Http::response('', 502, ['ngrok-error-code' => 'ERR_NGROK_3200']),
        ]);

        $model = $this->model();

        (new ModelHealthChecker())->check($model);

        $model->refresh();
        $this->assertSame('offline', $model->status);
        $this->assertSame('tunnel_down', $model->health_check_reason);
        // The raw words survive, because the administrator is the one who
        // restarts Kaggle and this code is what says which failure it was.
        $this->assertStringContainsString(
            'ERR_NGROK_3200',
            $model->health_check_error
        );
    }

    public function test_a_status_the_app_did_not_serve_is_unreachable(): void
    {
        // 502 without an ngrok header: something answered, but not FastAPI.
        Http::fake(['*' => Http::response('', 502)]);

        $model = $this->model();

        (new ModelHealthChecker())->check($model);

        $model->refresh();
        $this->assertSame('offline', $model->status);
        $this->assertSame('unreachable', $model->health_check_reason);
    }

    public function test_a_healthy_probe_clears_the_reason(): void
    {
        // 404 on the tunnel root means FastAPI answered: only /predict exists.
        Http::fake(['*' => Http::response('', 404)]);

        $model = $this->model([
            'status' => 'offline',
            'health_check_error' => 'Tunnel is not running (ERR_NGROK_3200)',
            'health_check_reason' => 'tunnel_down',
        ]);

        (new ModelHealthChecker())->check($model);

        $model->refresh();
        $this->assertSame('online', $model->status);
        $this->assertNull($model->health_check_reason);
        $this->assertNull($model->health_check_error);
    }
}
```

**Catatan jujur soal `slow`.** Cabang kelima, `REASON_SLOW`, **tidak diuji di sini** dan itu disengaja: ia dipicu oleh `microtime()` sungguhan yang melewati `SLOW_THRESHOLD_MS = 5000`, sementara `Http::fake()` menjawab seketika. Memaksakannya berarti menambah penyuntik waktu ke `ModelHealthChecker` demi satu test. Perilaku `trouble` yang benar-benar penting — bahwa ia ditawarkan kepada periset — diuji di Task 2 dengan menulis status itu langsung ke baris database.

- [ ] **Step 5: Jalankan test, pastikan gagal**

Run: `cd be && php artisan test --filter=ModelHealthCheckTest`
Expected: FAIL. Ketiga test alasan gagal dengan `Failed asserting that null matches expected 'no_endpoint'` dan seterusnya, karena `persist()` belum pernah menulis kolom itu.

- [ ] **Step 6: Tambahkan konstanta alasan**

Di `be/app/Services/ModelHealthChecker.php`, tepat setelah `public const TIMEOUT_SECONDS = 8;`:

```php
    /**
     * Why a model is not usable, in a form the client can branch on.
     *
     * Kept separate from the message in `health_check_error`: the message is
     * written for whoever restarts the worker, and naming an ngrok error code
     * to a researcher tells them nothing they can act on.
     */
    public const REASON_NO_ENDPOINT = 'no_endpoint';
    public const REASON_TUNNEL_DOWN = 'tunnel_down';
    public const REASON_UNREACHABLE = 'unreachable';
    public const REASON_SLOW = 'slow';
```

- [ ] **Step 7: Beri `persist()` parameter alasan**

Ganti tanda tangan di `be/app/Services/ModelHealthChecker.php:243-248`:

```php
    private function persist(
        Model $model,
        string $status,
        ?float $responseTime,
        ?string $error,
        ?string $reason = null
    ): array {
```

dan blok `$model->update([...])` tepat di bawahnya:

```php
        $model->update([
            'status' => $status,
            'last_health_check' => now(),
            'health_check_error' => $error,
            'health_check_reason' => $reason,
        ]);
```

Default `null` membuat cabang `online` di baris 203 benar tanpa disentuh: ia memanggil `persist($model, 'online', $responseTime, null)` dan kolomnya jadi `null`, yang memang yang diinginkan.

- [ ] **Step 8: Isi alasan di ketujuh pemanggil kegagalan**

Semuanya di `be/app/Services/ModelHealthChecker.php`. Nomor baris di bawah adalah posisi sebelum penyuntingan; kerjakan dari bawah ke atas supaya tidak bergeser.

Baris 195-200, cabang lambat:

```php
            return $this->persist(
                $model,
                'trouble',
                $responseTime,
                "Slow response: {$responseTime}ms",
                self::REASON_SLOW
            );
```

Baris 186-191, status yang bukan dari aplikasi:

```php
            return $this->persist(
                $model,
                'offline',
                $responseTime,
                "Endpoint unreachable (HTTP {$response->status()})",
                self::REASON_UNREACHABLE
            );
```

Baris 175-180, header galat ngrok:

```php
            return $this->persist(
                $model,
                'offline',
                $responseTime,
                "Tunnel is not running ({$ngrokError})",
                self::REASON_TUNNEL_DOWN
            );
```

Baris 139-141, tidak ada jawaban dari pool:

```php
                $results[$model->id] = $this->persist(
                    $model, 'offline', null, 'No response from the probe',
                    self::REASON_UNREACHABLE
                );
```

Baris 131-133, pengecualian di dalam pool:

```php
                $results[$model->id] = $this->persist(
                    $model, 'offline', null,
                    $this->cleanMessage($response->getMessage()),
                    self::REASON_UNREACHABLE
                );
```

Baris 97-99, tanpa endpoint di `checkMany`:

```php
                $results[$model->id] = $this->persist(
                    $model, 'offline', null, 'Endpoint URL is not set',
                    self::REASON_NO_ENDPOINT
                );
```

Baris 72, pengecualian di `check`:

```php
            return $this->persist(
                $model, 'offline', null,
                $this->cleanMessage($e->getMessage()),
                self::REASON_UNREACHABLE
            );
```

Baris 54, tanpa endpoint di `check`:

```php
            return $this->persist(
                $model, 'offline', null, 'Endpoint URL is not set',
                self::REASON_NO_ENDPOINT
            );
```

- [ ] **Step 9: Jalankan test, pastikan lulus**

Run: `cd be && php artisan test --filter=ModelHealthCheckTest`
Expected: PASS, 4 test.

- [ ] **Step 10: Jalankan seluruh test backend**

Run: `cd be && php artisan test`
Expected: PASS. Jumlahnya naik dari 242 jadi 246. Tidak ada yang gagal — `persist()` memakai parameter opsional, jadi tidak ada pemanggil lama yang rusak.

- [ ] **Step 11: Commit**

```bash
git add be/database/migrations/2026_08_22_090001_add_health_check_reason_to_models_table.php be/app/Models/Model.php be/app/Services/ModelHealthChecker.php be/tests/Feature/ModelHealthCheckTest.php
git commit -m "Record why a model is down in a form the client can act on"
```

---

### Task 2: Model lambat tetap ditawarkan, dan berhenti membocorkan nama host worker

**Files:**
- Modify: `be/app/Http/Controllers/API/MeController.php:66-97` (metode `models()`)
- Test: `be/tests/Feature/ModelAvailabilityTest.php` (baru)

**Interfaces:**
- Consumes: kolom `models.health_check_reason` dan konstanta dari Task 1.
- Produces: `GET /api/me/models` dan `POST /api/me/models/refresh` mengembalikan `is_available: true` untuk status `online` **dan** `trouble`; menambah field `health_check_reason`; **membuang** field `health_check_error`. Urutan: `online`, lalu `trouble`, lalu `offline`, lalu menurut nama.

- [ ] **Step 1: Tulis test yang gagal**

Berkas baru `be/tests/Feature/ModelAvailabilityTest.php`:

```php
<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Which models a researcher is allowed to send work to, and what they are
 * told about the ones they are not.
 */
class ModelAvailabilityTest extends TestCase
{
    use RefreshDatabase;

    private User $researcher;

    protected function setUp(): void
    {
        parent::setUp();

        $this->researcher = User::create([
            'username' => 'researcher',
            'name' => 'Researcher',
            'email' => 'researcher@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'is_active' => true,
        ]);
    }

    private function token(): string
    {
        return $this->tokenFor($this->researcher->email, 'password123');
    }

    private function model(array $overrides = []): Model
    {
        return Model::create(array_merge([
            'name' => 'deepCT TC-D',
            'version' => 'v1',
            'kind' => 'inference',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online',
            'is_active' => true,
            'max_concurrent_jobs' => 1,
        ], $overrides));
    }

    /**
     * A worker answering slowly is a working worker.
     *
     * The GPU sits in a Kaggle session behind an ngrok tunnel, so a probe
     * crossing five seconds is the ordinary case rather than the exception.
     * Reporting it unavailable took a live model out of the picker entirely.
     */
    public function test_a_slow_model_is_still_offered(): void
    {
        $this->model([
            'name' => 'Slow worker',
            'status' => 'trouble',
            'health_check_error' => 'Slow response: 7213ms',
            'health_check_reason' => 'slow',
        ]);

        $this->apiAs($this->token())->getJson('/api/me/models')
            ->assertOk()
            ->assertJsonPath('data.0.is_available', true)
            ->assertJsonPath('data.0.health_check_reason', 'slow');
    }

    public function test_a_dead_model_is_not_offered(): void
    {
        $this->model([
            'status' => 'offline',
            'health_check_error' => 'Tunnel is not running (ERR_NGROK_3200)',
            'health_check_reason' => 'tunnel_down',
        ]);

        $this->apiAs($this->token())->getJson('/api/me/models')
            ->assertOk()
            ->assertJsonPath('data.0.is_available', false)
            ->assertJsonPath('data.0.health_check_reason', 'tunnel_down');
    }

    /**
     * The picker selects the first available model on its own, so order is a
     * behaviour and not a presentation detail: a healthy worker sorting below
     * a slow one means every upload goes to the slow one by default.
     */
    public function test_a_healthy_model_sorts_above_a_slow_one(): void
    {
        // Created slow-first, and named so that ordering by name alone would
        // also put the slow one first. Only status ordering can pass this.
        $this->model([
            'name' => 'Alpha',
            'status' => 'trouble',
            'health_check_reason' => 'slow',
        ]);
        $this->model(['name' => 'Zulu', 'status' => 'online']);

        $this->apiAs($this->token())->getJson('/api/me/models')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Zulu')
            ->assertJsonPath('data.1.name', 'Alpha');
    }

    /**
     * A Guzzle failure message carries the URL it failed to reach, and
     * `cleanMessage()` only trims the message's length — it does not remove
     * the host. Sending that to a researcher hands over the very address
     * `models()` withholds `endpoint_url` to protect.
     */
    public function test_a_failure_message_does_not_leak_the_worker_hostname(): void
    {
        $this->model([
            'status' => 'offline',
            'endpoint_url' => 'https://secret-worker.ngrok-free.dev/predict',
            'health_check_error' =>
                'cURL error 7: Failed to connect to secret-worker.ngrok-free.dev port 443',
            'health_check_reason' => 'unreachable',
        ]);

        $response = $this->apiAs($this->token())->getJson('/api/me/models')
            ->assertOk();

        $this->assertStringNotContainsString(
            'secret-worker',
            $response->getContent()
        );
        // The reason code says everything the researcher needs and carries no
        // address at all.
        $response->assertJsonPath('data.0.health_check_reason', 'unreachable');
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd be && php artisan test --filter=ModelAvailabilityTest`
Expected: FAIL, keempatnya. `test_a_slow_model_is_still_offered` gagal dengan `Failed asserting that false matches expected true`; ketiga lainnya gagal karena `health_check_reason` belum ada di respons dan nama host masih ada di dalamnya.

- [ ] **Step 3: Perbaiki `models()`**

Di `be/app/Http/Controllers/API/MeController.php`, ganti seluruh isi metode `models()` (baris 66-97) menjadi:

```php
    public function models()
    {
        $models = Model::inference()
            ->where('is_active', true)
            // Explicit, because the picker selects the first available model
            // and the order therefore decides where work goes. This used to be
            // `orderByDesc('status')`, which put `online` above `offline` by
            // an accident of the alphabet — and would put `trouble` above both
            // now that a slow worker counts as available.
            ->orderByRaw(
                "CASE status WHEN 'online' THEN 0 WHEN 'trouble' THEN 1 ELSE 2 END"
            )
            ->orderBy('name')
            ->get([
                'id', 'name', 'version', 'status', 'description', 'accuracy',
                'last_health_check', 'health_check_reason',
            ]);

        return response()->json([
            'success' => true,
            'data' => $models->map(fn($m) => [
                'id' => $m->id,
                'name' => $m->name,
                'version' => $m->version,
                'status' => $m->status,
                'description' => $m->description,
                'accuracy' => $m->accuracy,
                // `trouble` means the worker answered, only slowly. It is a
                // live endpoint, and refusing it took a working model out of
                // the picker for the most ordinary condition this platform
                // has: a Kaggle GPU behind a tunnel.
                'is_available' => in_array($m->status, ['online', 'trouble'], true),
                // The client polls this every 10 seconds and shows how fresh
                // the answer is. Without the timestamp a stale scheduler looks
                // identical to a healthy model.
                'last_health_check' => $m->last_health_check?->toIso8601String(),
                // A code, not a sentence, and deliberately not the raw
                // message: `cleanMessage()` trims a Guzzle failure's length
                // but leaves the host in it, and this endpoint withholds
                // `endpoint_url` precisely so nobody can call the GPU worker
                // directly. The admin screen still shows the raw words.
                'health_check_reason' => $m->status === 'online'
                    ? null
                    : $m->health_check_reason,
            ]),
        ]);
    }
```

`orderByRaw` dengan `CASE` dipakai alih-alih `FIELD()` karena `FIELD()` khusus MySQL; `CASE` berjalan di MySQL maupun SQLite, jadi test tetap hidup bila konfigurasi test pindah.

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `cd be && php artisan test --filter=ModelAvailabilityTest`
Expected: PASS, 4 test.

- [ ] **Step 5: Jalankan seluruh test backend**

Run: `cd be && php artisan test`
Expected: PASS, 250 test. `AuthorizationTest::test_me_models_never_exposes_the_endpoint_url` dan `test_refreshing_models_probes_the_endpoint` sudah memakai `status: 'online'`, jadi keduanya tetap lulus tanpa perubahan.

- [ ] **Step 6: Muat ulang server, lalu periksa langsung**

Run: `cd be && npm run octane:reset`

Lalu, dengan token periset yang sah:

```bash
curl -s -H "Authorization: Bearer <token>" http://localhost:8000/api/me/models
```

Expected: setiap entri punya `health_check_reason` dan **tidak** punya `health_check_error`. `route:list` bukan bukti; yang membuktikan adalah respons ini.

- [ ] **Step 7: Commit**

```bash
git add be/app/Http/Controllers/API/MeController.php be/tests/Feature/ModelAvailabilityTest.php
git commit -m "Offer a slow worker instead of calling it dead, and stop handing out its hostname"
```

---

### Task 3: Satu tempat yang mengubah kode alasan jadi kalimat

**Files:**
- Create: `fe/lib/models/model_status_message.dart`
- Modify: `fe/lib/services/me_service.dart:9-61` (kelas `AvailableModel`)
- Modify: `fe/lib/models/model_info.dart:17,35,77,87-89` (kelas `ModelInfo`)
- Test: `fe/test/model_status_message_test.dart` (baru)

**Interfaces:**
- Consumes: field `health_check_reason` dari Task 2.
- Produces: fungsi tingkat atas `String modelStatusMessage(String? reason)`; field `String? healthCheckReason` pada `AvailableModel` dan `ModelInfo`; getter `bool get isOnline` pada `AvailableModel`. `ModelInfo.isOnline` / `isTrouble` / `isOffline` sudah ada di baris 87-89 dan tidak berubah.

- [ ] **Step 1: Tulis test yang gagal**

Berkas baru `fe/test/model_status_message_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/model_status_message.dart';

void main() {
  test('a dead tunnel reads as a disconnected server, not as ngrok', () {
    final message = modelStatusMessage('tunnel_down');

    expect(message, contains('disconnected'));
    expect(message.toLowerCase(), isNot(contains('tunnel')));
    expect(message.toLowerCase(), isNot(contains('ngrok')));
  });

  test('a model never configured is not described as a dead server', () {
    // Telling someone to restart something that was never set up sends them
    // looking for a machine that does not exist.
    final message = modelStatusMessage('no_endpoint');

    expect(message, contains('no server address'));
    expect(message, isNot(contains('not responding')));
  });

  test('a slow worker says the job will take longer, not that it failed', () {
    final message = modelStatusMessage('slow');

    expect(message, contains('slowly'));
    expect(message, contains('longer'));
  });

  test('an unreachable worker asks for an administrator', () {
    expect(modelStatusMessage('unreachable'), contains('not responding'));
  });

  test('a row written before the reason column existed still reads sensibly', () {
    // Every model row has a null reason until the next health check writes
    // one, which is at most a minute after the migration runs.
    expect(modelStatusMessage(null), contains('not responding'));
    expect(modelStatusMessage('something_new'), contains('not responding'));
  });

  test('no message names an HTTP status code or an error identifier', () {
    for (final reason in [
      'tunnel_down',
      'no_endpoint',
      'slow',
      'unreachable',
      null,
    ]) {
      expect(
        modelStatusMessage(reason),
        isNot(matches(RegExp(r'HTTP \d|ERR_|\d{3,}'))),
        reason: 'reason "$reason" leaked machine detail',
      );
    }
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/model_status_message_test.dart`
Expected: FAIL saat kompilasi — `Error: Couldn't resolve the package 'fe/models/model_status_message.dart'`.

- [ ] **Step 3: Tulis fungsi pemetaannya**

Berkas baru `fe/lib/models/model_status_message.dart`:

```dart
/// What a researcher is told when a model cannot be used.
///
/// The health checker writes two things: its own words in
/// `health_check_error` — "Tunnel is not running (ERR_NGROK_3200)",
/// "Endpoint unreachable (HTTP 502)" — and a code in `health_check_reason`.
/// The words are written for whoever restarts the Kaggle session, which is an
/// administrator; the admin screen still shows them verbatim, because
/// ERR_NGROK_3200 is the only thing that says which failure this is.
///
/// A researcher is not that person. They are trying to find out whether they
/// can upload, and "tunnel" names infrastructure they have no access to. So
/// everything outside the admin screen reads a sentence chosen from the code
/// instead — one place, so the status strip and the upload screen cannot drift
/// apart.
String modelStatusMessage(String? reason) {
  switch (reason) {
    case 'tunnel_down':
      return 'The model server is disconnected. '
          'Ask an administrator to bring it back.';

    case 'no_endpoint':
      // Not a server that died: a registration that was never finished.
      // Sending someone to restart it would send them looking for a machine
      // that does not exist.
      return 'This model has no server address yet. '
          'Ask an administrator to finish setting it up.';

    case 'slow':
      // The only reason that is not a refusal. The worker answered, so the
      // job can go ahead — this exists to say so before someone presses the
      // button and wonders why it is taking so long.
      return 'The model server is answering slowly. '
          'Your job may take longer than usual.';

    case 'unreachable':
    default:
      // Also the answer for null and for any code added later that this build
      // has not heard of. A row written before the reason column existed has
      // a null reason and an offline status; it has to stay sensible until the
      // next health check fills it in, at most a minute later.
      return 'The model server is not responding. '
          'Ask an administrator to bring it back.';
  }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/model_status_message_test.dart`
Expected: PASS, 6 test.

- [ ] **Step 5: Bawa kode alasan ke `AvailableModel`**

Di `fe/lib/services/me_service.dart`, ganti field `healthCheckError` beserta komentarnya (baris 23-26):

```dart
  /// Why it cannot be used, as a code rather than a sentence — `tunnel_down`,
  /// `unreachable`, `no_endpoint`, `slow`. Turned into words by
  /// [modelStatusMessage].
  ///
  /// The checker's raw message is deliberately not sent to this endpoint: it
  /// carries the worker's hostname, which `/api/me/models` withholds on
  /// purpose.
  final String? healthCheckReason;
```

Di konstruktor, ganti `this.healthCheckError,` menjadi `this.healthCheckReason,`.

Di `fromJson`, ganti baris `healthCheckError: json['health_check_error']?.toString(),` menjadi:

```dart
      healthCheckReason: json['health_check_reason']?.toString(),
```

Lalu tambahkan getter di samping `label`, di akhir kelas:

```dart
  /// Answering, and answering promptly. [isAvailable] is wider: it also
  /// covers a worker that answers slowly, which can still take work.
  bool get isOnline => status == 'online';
```

- [ ] **Step 6: Bawa kode alasan ke `ModelInfo`**

Di `fe/lib/models/model_info.dart`, **di samping** `healthCheckError` yang tetap ada — layar admin memakai keduanya. Setelah baris 17 (`final String? healthCheckError;`):

```dart
  /// The same failure as [healthCheckError], as a code the client can branch
  /// on. The admin screen shows both: the sentence, and the checker's own
  /// words underneath it.
  final String? healthCheckReason;
```

Di konstruktor, setelah `this.healthCheckError,`:

```dart
    this.healthCheckReason,
```

Di `fromJson`, setelah baris `healthCheckError: json['health_check_error']?.toString(),`:

```dart
      healthCheckReason: json['health_check_reason']?.toString(),
```

`isOnline`, `isTrouble`, `isOffline` di baris 87-89 sudah ada dan tidak berubah.

- [ ] **Step 7: Analisa, dan perhatikan kegagalan yang diharapkan**

Run: `cd fe && flutter analyze`
Expected: FAIL. `model_status_strip.dart:139` dan `model_management_screen.dart` masih menyebut `healthCheckError` pada `AvailableModel`, yang baru saja dihapus. Ini benar dan diperbaiki di Task 4; `ModelInfo.healthCheckError` tidak dihapus, jadi layar admin belum rusak.

- [ ] **Step 8: Commit**

```bash
git add fe/lib/models/model_status_message.dart fe/lib/models/model_info.dart fe/lib/services/me_service.dart fe/test/model_status_message_test.dart
git commit -m "Say why a model is down in words a researcher can act on"
```

Commit ini sengaja meninggalkan `flutter analyze` dalam keadaan gagal — Task 4 adalah pasangannya dan menutupnya. Bila itu mengganggu, gabungkan Task 3 dan 4 menjadi satu commit.

---

### Task 4: Strip status punya tiga warna

**Files:**
- Modify: `fe/lib/widgets/model_status_strip.dart:118-141` (bagian akhir `build`) dan bagian `import`
- Test: `fe/test/model_status_test.dart` — **ditulis ulang**, bukan ditambahi

**Interfaces:**
- Consumes: `modelStatusMessage`, `AvailableModel.healthCheckReason`, `AvailableModel.isOnline` dari Task 3.
- Produces: tidak ada yang dipakai task lain.

- [ ] **Step 1: Tulis ulang testnya**

Di `fe/test/model_status_test.dart`, ganti pembantu `_model` (baris 9-23) menjadi:

```dart
AvailableModel _model({
  int id = 1,
  String status = 'online',
  String? reason,
  DateTime? checkedAt,
}) => AvailableModel(
  id: id,
  name: 'deepCT TC-D',
  version: 'v1.0',
  status: status,
  // Matches the server: a slow worker answered, so it can still take work.
  isAvailable: status == 'online' || status == 'trouble',
  lastHealthCheck: checkedAt ?? DateTime.now(),
  healthCheckReason: reason,
);
```

Ganti seluruh test `'shows the checker\'s own words when the model is down'` (baris 50-70) dengan tiga test berikut:

```dart
  testWidgets('tells a researcher what to do without naming the tunnel', (
    tester,
  ) async {
    // The old copy said "Tunnel is not running (ERR_NGROK_3200)". It was
    // right that a researcher needs to be told what to do, and wrong about
    // who does it: they have no access to the tunnel. The administrator does,
    // and still sees the raw code on the model management screen.
    ModelStatusStrip.debugLoader = () async => [
      _model(status: 'offline', reason: 'tunnel_down'),
    ];

    await tester.pumpWidget(_host(const ModelStatusStrip()));
    await tester.pumpAndSettle();

    expect(find.text('Model offline'), findsOneWidget);
    expect(find.textContaining('Ask an administrator'), findsOneWidget);
    expect(find.textContaining('ERR_NGROK'), findsNothing);
    expect(find.textContaining('Tunnel'), findsNothing);
  });

  testWidgets('a slow worker is amber and is not called offline', (
    tester,
  ) async {
    // The GPU sits in a Kaggle session behind a tunnel, so a probe past five
    // seconds is ordinary. Painting it red said the model was dead when it
    // was answering.
    ModelStatusStrip.debugLoader = () async => [
      _model(status: 'trouble', reason: 'slow'),
    ];

    await tester.pumpWidget(_host(const ModelStatusStrip()));
    await tester.pumpAndSettle();

    expect(find.text('Model offline'), findsNothing);
    expect(find.text('Model slow'), findsOneWidget);
    expect(find.textContaining('take longer'), findsOneWidget);
  });

  testWidgets('one healthy worker outranks a slow one in the summary', (
    tester,
  ) async {
    ModelStatusStrip.debugLoader = () async => [
      _model(id: 1, status: 'online'),
      _model(id: 2, status: 'trouble', reason: 'slow'),
    ];

    await tester.pumpWidget(_host(const ModelStatusStrip()));
    await tester.pumpAndSettle();

    // Counted against healthy, not against available: two of two "available"
    // would hide the fact that one of them is limping.
    expect(find.text('1 of 2 models online'), findsOneWidget);
  });
```

Dalam test `'counts a partial outage'` (baris ~84), ganti `_model(id: 2, status: 'offline')` menjadi `_model(id: 2, status: 'offline', reason: 'tunnel_down')`. Harapannya, `'1 of 2 models online'`, tidak berubah.

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/model_status_test.dart`
Expected: FAIL saat kompilasi — `healthCheckReason` sekarang ada tapi `model_status_strip.dart` masih memanggil `healthCheckError` yang sudah tidak ada di `AvailableModel`.

- [ ] **Step 3: Tambahkan import**

Di `fe/lib/widgets/model_status_strip.dart`, setelah `import '../services/me_service.dart';`:

```dart
import '../models/model_status_message.dart';
```

- [ ] **Step 4: Tulis ulang tiga cabang terakhir `build`**

Ganti dari baris 118 (`final online = _models.where(...)`) sampai baris 141 (penutup `return _Bar(...)` terakhir) dengan:

```dart
    // Split three ways, not two. `isAvailable` also covers a worker that
    // answers slowly, and summarising that as "online" would hide the only
    // thing worth saying about it.
    final healthy = _models.where((m) => m.isOnline).toList();
    final usable = _models.where((m) => m.isAvailable).toList();

    if (healthy.isNotEmpty) {
      return _Bar(
        color: AppTheme.success,
        icon: Icons.check_circle_outline,
        title: healthy.length == _models.length
            ? 'Model online'
            : '${healthy.length} of ${_models.length} models online',
        detail: '${healthy.first.label} · checked '
            '${_ago(healthy.first.lastHealthCheck)}',
      );
    }

    // Nothing is fully healthy, but something still answers. Amber rather
    // than red, because the work can go ahead — it will just take longer,
    // which is what the message says.
    if (usable.isNotEmpty) {
      final slow = usable.first;

      return _Bar(
        color: AppTheme.warning,
        icon: Icons.hourglass_empty,
        title: 'Model slow',
        detail: '${modelStatusMessage(slow.healthCheckReason)} · checked '
            '${_ago(slow.lastHealthCheck)}',
      );
    }

    final first = _models.first;

    return _Bar(
      color: AppTheme.error,
      icon: Icons.error_outline,
      title: 'Model offline',
      // The reason code turned into words. The checker's own message names
      // the tunnel and the HTTP status; that belongs to the administrator who
      // restarts the worker, and stays on the model management screen.
      detail: '${modelStatusMessage(first.healthCheckReason)} · '
          'checked ${_ago(first.lastHealthCheck)}',
    );
  }
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/model_status_test.dart`
Expected: PASS, 9 test.

- [ ] **Step 6: Analisa**

Run: `cd fe && flutter analyze`
Expected: FAIL masih, tapi hanya di `model_management_screen.dart` bila ia sudah disentuh. Bila `flutter analyze` bersih di sini, itu juga benar: `ModelInfo.healthCheckError` tidak dihapus, jadi layar admin masih mengkompilasi apa adanya.

- [ ] **Step 7: Commit**

```bash
git add fe/lib/widgets/model_status_strip.dart fe/test/model_status_test.dart
git commit -m "Paint a slow worker amber, and stop telling researchers about tunnels"
```

---

### Task 5: Layar unggah menerima model lambat dan menjelaskan yang tidak

**Files:**
- Modify: `fe/lib/screens/user/upload_screen.dart:668-706` (widget `_ModelOption`)
- Test: `fe/test/upload_model_picker_test.dart` (baru)

**Interfaces:**
- Consumes: `modelStatusMessage`, `AvailableModel.isOnline`, `AvailableModel.healthCheckReason` dari Task 3.
- Produces: tidak ada yang dipakai task lain.

Tidak ada perubahan pada baris 488 (`onTap: model.isAvailable ? ... : null`), baris 261 (`_canSubmit`), maupun baris 85 dan 118 (pemilihan otomatis). Ketiganya membaca `isAvailable`, yang sudah benar begitu Task 2 mendarat — dan pemilihan otomatis mengambil model sehat lebih dulu karena Task 2 memperbaiki urutannya.

- [ ] **Step 1: Tulis test yang gagal**

Berkas baru `fe/test/upload_model_picker_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/model_status_message.dart';
import 'package:fe/services/me_service.dart';
import 'package:fe/theme/app_theme.dart';

/// Mirrors what `_ModelOption` renders. `_ModelOption` is private to
/// `upload_screen.dart`, and driving the whole screen would need a live API
/// client — so this pins the two decisions the widget makes rather than the
/// widget itself, and the widget is checked by eye against them.
///
/// The decisions: an available-but-slow model is amber and selectable, and a
/// model that is not online carries a sentence saying why.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  Color badgeColour(AvailableModel m) => m.isOnline
      ? AppTheme.success
      : (m.isAvailable ? AppTheme.warning : AppTheme.error);

  AvailableModel model(String status, String? reason) => AvailableModel(
    id: 1,
    name: 'deepCT TC-D',
    version: 'v1.0',
    status: status,
    isAvailable: status == 'online' || status == 'trouble',
    lastHealthCheck: DateTime.now(),
    healthCheckReason: reason,
  );

  test('a slow model is amber, not red, and can still be chosen', () {
    final slow = model('trouble', 'slow');

    expect(badgeColour(slow), AppTheme.warning);
    expect(slow.isAvailable, isTrue);
  });

  test('a dead model is red and cannot be chosen', () {
    final dead = model('offline', 'tunnel_down');

    expect(badgeColour(dead), AppTheme.error);
    expect(dead.isAvailable, isFalse);
  });

  test('a healthy model is green', () {
    expect(badgeColour(model('online', null)), AppTheme.success);
  });

  testWidgets('the reason a model cannot be used is spelled out', (
    tester,
  ) async {
    final dead = model('offline', 'tunnel_down');

    await tester.pumpWidget(
      host(Text(modelStatusMessage(dead.healthCheckReason))),
    );

    expect(find.textContaining('Ask an administrator'), findsOneWidget);
    expect(find.textContaining('ERR_NGROK'), findsNothing);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/upload_model_picker_test.dart`
Expected: PASS sebenarnya — test ini mengunci keputusan yang sudah benar begitu Task 2 dan 3 mendarat. Ia ada supaya keputusan itu tidak diam-diam dibalik nanti. Yang belum benar adalah widget-nya, dan itu diperiksa dengan mata di Step 5.

- [ ] **Step 3: Tambahkan import**

Di `fe/lib/screens/user/upload_screen.dart`, di antara import model yang sudah ada:

```dart
import '../../models/model_status_message.dart';
```

- [ ] **Step 4: Beri lencana tiga warna dan satu kalimat**

Di `fe/lib/screens/user/upload_screen.dart`, di dalam `_ModelOption.build`, ganti blok `Expanded(child: Column(...))` (baris 669-688) dengan:

```dart
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: disabled ? AppTheme.textMuted : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (model.accuracy != null)
                      Text(
                        'Accuracy ${model.accuracy!.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    // Anything short of healthy gets a sentence. For a slow
                    // worker that is not a refusal — it is selectable, and
                    // this says why it will feel sluggish before anyone
                    // presses the button and wonders.
                    if (!model.isOnline) ...[
                      const SizedBox(height: 4),
                      Text(
                        modelStatusMessage(model.healthCheckReason),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: model.isAvailable
                              ? AppTheme.warning
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
```

lalu ganti `Container` lencana (baris 689-705) dengan:

```dart
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: model.isOnline
                    ? AppTheme.successLight
                    : (model.isAvailable
                          ? AppTheme.warningLight
                          : AppTheme.errorLight),
                child: Text(
                  model.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: model.isOnline
                        ? AppTheme.success
                        : (model.isAvailable
                              ? AppTheme.warning
                              : AppTheme.error),
                  ),
                ),
              ),
```

- [ ] **Step 5: Analisa dan jalankan seluruh test Flutter**

Run: `cd fe && flutter analyze && flutter test`
Expected: `flutter analyze` bersih, seluruh test lulus.

- [ ] **Step 6: Commit**

```bash
git add fe/lib/screens/user/upload_screen.dart fe/test/upload_model_picker_test.dart
git commit -m "Let a slow model be chosen, and say why a dead one cannot"
```

---

### Task 6: Admin melihat kalimatnya sekaligus kode aslinya

**Files:**
- Modify: `fe/lib/screens/admin/model_management_screen.dart:404-421` dan bagian `import`

**Interfaces:**
- Consumes: `modelStatusMessage`, `ModelInfo.healthCheckReason`, `ModelInfo.isTrouble` dari Task 3.
- Produces: tidak ada yang dipakai task lain.

- [ ] **Step 1: Tambahkan import**

Di `fe/lib/screens/admin/model_management_screen.dart`, di antara import model yang sudah ada:

```dart
import '../../models/model_status_message.dart';
```

- [ ] **Step 2: Ganti kotak error jadi dua baris**

Ganti blok `if (model.healthCheckError != null && ...)` (baris 404-421) dengan:

```dart
                  if (model.healthCheckError != null &&
                      model.healthCheckError!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: model.isTrouble
                          ? AppTheme.warningLight
                          : AppTheme.errorLight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            modelStatusMessage(model.healthCheckReason),
                            style: TextStyle(
                              fontSize: 11,
                              color: model.isTrouble
                                  ? AppTheme.warning
                                  : AppTheme.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // The checker's own words, kept only here. The
                          // administrator is the one who restarts the Kaggle
                          // session, and ERR_NGROK_3200 is the only thing
                          // that says which failure this is.
                          Text(
                            model.healthCheckError!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
```

- [ ] **Step 3: Analisa dan jalankan seluruh test Flutter**

Run: `cd fe && flutter analyze && flutter test`
Expected: `flutter analyze` bersih, seluruh test lulus.

- [ ] **Step 4: Periksa dengan mata**

Jalankan aplikasi, masuk sebagai admin, buka Model Management dengan satu model yang endpoint-nya mati.

Expected: kartu model menampilkan `The model server is disconnected. Ask an administrator to bring it back.` dengan `Tunnel is not running (ERR_NGROK_3200)` di bawahnya dengan gaya lebih kecil dan redup.

- [ ] **Step 5: Commit**

```bash
git add fe/lib/screens/admin/model_management_screen.dart
git commit -m "Give the administrator the sentence and the error code both"
```

---

### Task 7: Daftar aktivitas punya area scroll sendiri

**Files:**
- Modify: `fe/lib/screens/user/user_home_screen.dart:201-214`
- Modify: `fe/lib/screens/admin/dashboard_home_screen.dart:230-243`
- Test: `fe/test/recent_activity_scroll_test.dart` (baru)

**Interfaces:**
- Consumes: tidak ada.
- Produces: tidak ada. Berdiri sendiri sepenuhnya dan boleh dikerjakan sebelum Task 1 bila diinginkan.

- [ ] **Step 1: Tulis test yang gagal**

Berkas baru `fe/test/recent_activity_scroll_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape both dashboards use for their recent-activity list.
///
/// Reproduced here rather than driving the real screens, which each fetch
/// four endpoints on `initState`. What is being pinned is the layout
/// decision, and it can be wrong in two opposite directions — so both are
/// tested.
Widget activityBox(int rows) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: rows,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  SizedBox(height: 72, child: Text('row $index')),
            ),
          ),
          const Text('below the list'),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('a long list is capped and scrolls inside its own box', (
    tester,
  ) async {
    await tester.pumpWidget(activityBox(20));
    await tester.pumpAndSettle();

    final box = tester.getSize(find.byType(ListView));
    expect(box.height, lessThanOrEqualTo(320));

    // The whole point: what follows the list is reachable without scrolling
    // past twenty rows first.
    expect(find.text('below the list'), findsOneWidget);
  });

  testWidgets('a short list does not pad itself out to the cap', (
    tester,
  ) async {
    // This is the case that catches `shrinkWrap` being dropped along with
    // `NeverScrollableScrollPhysics`. A bounded ListView without shrinkWrap
    // fills all 320px whether it holds two rows or twenty.
    await tester.pumpWidget(activityBox(2));
    await tester.pumpAndSettle();

    final box = tester.getSize(find.byType(ListView));
    expect(box.height, lessThan(200));
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/recent_activity_scroll_test.dart`
Expected: PASS. Test ini mengunci bentuk yang benar; ia sengaja tidak menggerakkan layar sungguhan. Yang membuktikan layarnya ikut berubah adalah Step 5.

- [ ] **Step 3: Perbaiki dasbor periset**

Di `fe/lib/screens/user/user_home_screen.dart`, ganti blok `Container(...)` di baris 201-214 dengan:

```dart
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                ),
                child: ConstrainedBox(
                  // Roughly four rows: long enough to read as a list, short
                  // enough that the dashboard stays one screen on a phone.
                  // Before this the list expanded to its full height and
                  // pushed everything under it off the page.
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    // Kept deliberately. With a bounded height and no
                    // shrinkWrap the list fills all 320px even when it holds
                    // two rows; this makes it as tall as its content, up to
                    // the cap. What makes it scroll is the removal of
                    // NeverScrollableScrollPhysics, not of shrinkWrap.
                    shrinkWrap: true,
                    itemCount: _recent.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        UserActivityTile(activity: _recent[index]),
                  ),
                ),
              ),
```

- [ ] **Step 4: Perbaiki dasbor admin**

Di `fe/lib/screens/admin/dashboard_home_screen.dart`, ganti blok `Container(...)` di baris 230-243 dengan bentuk yang sama, dengan dua perbedaan: `_recentActivities` menggantikan `_recent`, dan `_ActivityTile` menggantikan `UserActivityTile`:

```dart
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                ),
                child: ConstrainedBox(
                  // Roughly four rows: long enough to read as a list, short
                  // enough that the dashboard stays one screen on a phone.
                  // Before this the list expanded to its full height and
                  // pushed everything under it off the page.
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    // Kept deliberately. With a bounded height and no
                    // shrinkWrap the list fills all 320px even when it holds
                    // two rows; this makes it as tall as its content, up to
                    // the cap. What makes it scroll is the removal of
                    // NeverScrollableScrollPhysics, not of shrinkWrap.
                    shrinkWrap: true,
                    itemCount: _recentActivities.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _ActivityTile(activity: _recentActivities[index]),
                  ),
                ),
              ),
```

- [ ] **Step 5: Analisa, test, lalu periksa dengan mata**

Run: `cd fe && flutter analyze && flutter test`
Expected: bersih, seluruh test lulus.

Lalu jalankan aplikasinya dengan setidaknya sepuluh baris aktivitas, sebagai admin dan sebagai periset.

Expected: kotak aktivitas berhenti sekitar empat baris dan menggulung di dalam dirinya sendiri; halaman di belakangnya tidak lagi memanjang mengikuti jumlah baris.

- [ ] **Step 6: Commit**

```bash
git add fe/lib/screens/user/user_home_screen.dart fe/lib/screens/admin/dashboard_home_screen.dart fe/test/recent_activity_scroll_test.dart
git commit -m "Let recent activity scroll in its own box instead of stretching the page"
```

---

### Task 8: Teks bisa disalin di seluruh aplikasi

**Files:**
- Modify: `fe/lib/screens/user/user_shell.dart:309` (`body:`)
- Modify: `fe/lib/screens/admin/admin_shell.dart:319` (`body:`)
- Modify: `fe/lib/screens/landing/landing_page.dart:176` (`body:`)
- Modify: `fe/lib/widgets/app_dialog.dart:39-43` (isi `Dialog`)
- Test: `fe/test/selectable_text_test.dart` (baru)

**Interfaces:**
- Consumes: tidak ada.
- Produces: tidak ada. Berdiri sendiri sepenuhnya.

Sudah diperiksa sebelum rencana ini ditulis: **tidak ada satu pun `onLongPress` di `fe/lib`**, jadi gestur tekan-lama yang dipakai `SelectionArea` di ponsel tidak merebut gestur milik widget lain.

- [ ] **Step 1: Tulis test yang gagal**

Berkas baru `fe/test/selectable_text_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/widgets/app_dialog.dart';

void main() {
  testWidgets('a dialog\'s text can be selected and copied', (tester) async {
    // The dialog needs its own SelectionArea: showDialog pushes a route into
    // the overlay, so it is not a descendant of whatever wraps the shell.
    // This is the one that gets missed.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAppDialog<void>(
                context: context,
                builder: (_) => const Text('a generated password'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('a generated password'),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/selectable_text_test.dart`
Expected: FAIL dengan `Expected: exactly one matching candidate` sementara yang ditemukan nol widget — belum ada `SelectionArea` di mana pun.

- [ ] **Step 3: Bungkus isi dialog**

Di `fe/lib/widgets/app_dialog.dart`, di dalam `showAppDialog`, ganti anak `ConstrainedBox`:

```dart
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.min(maxWidth, size.width * 0.9),
              maxHeight: size.height * 0.85,
            ),
            // Its own, because `showDialog` pushes a route into the overlay:
            // a SelectionArea around a shell's body is not an ancestor of
            // anything shown here. Dialogs are where the values worth copying
            // live — a generated password, an account's credentials.
            child: SelectionArea(
              child: SingleChildScrollView(child: builder(dialogContext)),
            ),
          ),
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/selectable_text_test.dart`
Expected: PASS.

- [ ] **Step 5: Bungkus badan ketiga shell**

Di `fe/lib/screens/user/user_shell.dart`, `body:` saat ini berbentuk:

```dart
      body: SafeArea(
        bottom: false,
        child: Row(
```

Menjadi:

```dart
      // One SelectionArea over the whole body rather than a SelectableText
      // per label: selection then runs across widgets, so a block spanning
      // several rows can be swept in one gesture. Text fields are unaffected
      // — SelectionArea skips EditableText — and there is no onLongPress
      // anywhere in the app for it to fight with.
      body: SelectionArea(
        child: SafeArea(
          bottom: false,
          child: Row(
```

dengan satu `)` tambahan di penutup `body:`.

Lakukan hal yang sama pada `fe/lib/screens/admin/admin_shell.dart` (baris 319) dan `fe/lib/screens/landing/landing_page.dart` (baris 176). Ketiganya berbentuk `body: SafeArea(...)`, jadi penyuntingannya identik; komentarnya cukup ditulis sekali, di `user_shell.dart`.

Tiga `SelectableText` yang sudah ada — `access_requests_screen.dart:390`, `activity_logs_screen.dart:500`, `user_management_screen.dart:183` — **dibiarkan**. Keduanya hidup berdampingan, dan mencabutnya hanya menambah risiko.

- [ ] **Step 6: Analisa dan jalankan seluruh test Flutter**

Run: `cd fe && flutter analyze && flutter test`
Expected: bersih, seluruh test lulus.

- [ ] **Step 7: Bangun APK dan coba di ponsel sungguhan**

Run: `cd fe && flutter build apk --release`

Pasang, lalu di perangkat:

1. Tekan lama sebuah teks di dasbor — pegangan seleksi muncul, "Copy" bisa ditekan.
2. Tekan lama teks di dalam dialog, misalnya kata sandi hasil reset admin.
3. Ketuk tombol dan baris daftar seperti biasa — tidak ada yang tertelan.
4. Gulung daftar aktivitas dari Task 7.

Ini bukan pelengkap. Perilaku seleksi di ponsel tidak terlihat dari test widget, dan keluhan yang memulai bagian A justru datang dari perangkat.

- [ ] **Step 8: Commit**

```bash
git add fe/lib/screens/user/user_shell.dart fe/lib/screens/admin/admin_shell.dart fe/lib/screens/landing/landing_page.dart fe/lib/widgets/app_dialog.dart fe/test/selectable_text_test.dart
git commit -m "Let any text in the app be selected and copied"
```

---

### Task 9: Catat dan centang

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `ROADMAP.md` (§12, item A)

**Interfaces:**
- Consumes: seluruh task sebelumnya, selesai dan terverifikasi.
- Produces: tidak ada.

- [ ] **Step 1: Jalankan verifikasi penuh dan baca hasilnya**

```bash
cd be && php artisan test
cd ../fe && flutter analyze
flutter test
flutter build apk --release
```

Catat angka sebenarnya yang keluar. Aturan 1 di CLAUDE.md: jalankan perintahnya, baca hasilnya, baru tulis statusnya.

- [ ] **Step 2: Tulis entri CHANGELOG**

Tambahkan di puncak `CHANGELOG.md`, mengikuti bentuk entri yang sudah ada. Sebutkan **mengapa**, bukan hanya apa: `trouble` diperlakukan tersedia karena worker GPU di balik tunnel memang lambat dan bukan mati; pesan mentah berhenti dikirim ke periset karena ia membawa nama host yang sengaja dirahasiakan endpoint itu.

- [ ] **Step 3: Centang item A di ROADMAP**

Di `ROADMAP.md` §12, ubah `- [ ] **A — Bersih-bersih UI.**` menjadi `- [x]`, dan tambahkan satu kalimat berisi apa yang benar-benar diamati — termasuk bahwa `REASON_SLOW` tidak punya test otomatis dan mengapa.

Bila ada bagian yang tidak selesai, katakan begitu di sana. Aturan 4 CLAUDE.md: pekerjaan setengah jadi yang diberi label setengah jadi tidak masalah; yang diberi label selesai memakan waktu satu hari orang lain.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md ROADMAP.md
git commit -m "Record what part A changed and why"
```

---

## Catatan untuk pelaksana

**Urutan itu penting sampai Task 6.** Task 3 sengaja meninggalkan `flutter analyze` dalam keadaan gagal — ia menghapus `AvailableModel.healthCheckError` yang masih dipakai Task 4. Bila Anda menjalankan task-nya di sesi terpisah, jalankan 3 dan 4 berurutan.

Task 7 dan 8 tidak bergantung pada apa pun. Keduanya bisa dikerjakan lebih dulu bila backend sedang tidak bisa dijalankan.

**Yang berubah dari spec, dan alasannya.** Spec menyebut ada test backend yang menegaskan model `trouble` tidak tersedia dan perlu ditulis ulang. Setelah `be/tests` ditelusuri, test seperti itu **tidak ada** — yang ada memakai `status: 'online'` dan tetap lulus. Jadi Task 2 hanya menambah test, tidak menulis ulang. Yang benar-benar ditulis ulang hanya sisi Flutter, `fe/test/model_status_test.dart`.

**Satu hal yang ditemukan saat rencana ini disusun dan tidak ada di spec:** `cleanMessage()` di `ModelHealthChecker.php:282` hanya memotong panjang pesan, meski komentarnya mengklaim membuang URL. Pesan seperti `cURL error 7: Failed to connect to abc123.ngrok-free.dev port 443` dikirim apa adanya ke `/api/me/models`, padahal `MeController.php:60-63` merahasiakan `endpoint_url` justru supaya periset tidak bisa memanggil worker GPU langsung. Task 2 menutupnya dengan berhenti mengirim `health_check_error` ke endpoint itu sama sekali, dan menguncinya dengan
`test_a_failure_message_does_not_leak_the_worker_hostname`.
