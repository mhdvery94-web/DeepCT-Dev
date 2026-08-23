# Bagian D — Training milik periset: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Periset menjalankan training dari datanya sendiri, melihat empat metrik per epoch, dan menggeser gambar contoh untuk melihat modelnya membaik — sementara tab Training admin hilang tanpa kemampuannya ikut hilang.

**Architecture:** Trainer diubah untuk menghitung SSIM dan MSE di samping PSNR yang sudah ada, dan mengunggah satu PNG contoh tiap epoch ke endpoint baru. Platform menyimpannya di `training_samples` dan menyajikannya lewat `FrameStackViewer` dari bagian C, dengan epoch sebagai sumbunya. Tab Training admin dihapus setelah `registerModel` dan penghapusan pindah ke Model Management.

**Tech Stack:** Laravel 12 + Octane/RoadRunner, Flutter, MySQL, TensorFlow (di Kaggle, bukan di sini).

## Global Constraints

- **`metrics` tetap JSON bebas.** Tidak ada kolom baru untuk metrik — komentar migrasinya menjelaskan kenapa, dan alasan itu masih berlaku.
- **`loss` tetap dikirim** dengan nilai yang sama seperti `mae`. Job yang sudah tercatat memakai kunci itu.
- **Metrik yang tidak ada ditampilkan `—`, bukan `0`.** Nol akan terbaca sebagai hasil pengukuran.
- **Satu triplet uji tetap** untuk gambar contoh. Membandingkan epoch dengan triplet berbeda tidak mengatakan apa pun tentang modelnya.
- **Batas 4 MB per sampel**, sejajar `NewsPost::MAX_IMAGE_BYTES`.
- **Bahasa antarmuka Inggris**, sudut kotak (`BorderRadius.zero`), `withValues(alpha:)`.
- **`php artisan route:clear`** setelah mengubah rute, atau perubahannya tidak terlihat di mana pun (CLAUDE.md).
- **Dasar sebelum D:** backend 274 test, Flutter 162 test, `flutter analyze` bersih.
- **D tidak bisa diverifikasi penuh di sini.** Perubahan `script-api-train-deepct.py` hanya terbukti dengan menjalankannya di Kaggle, dan training memakan berjam-jam.

---

### Task 1: Trainer menghitung empat metrik

**Files:**
- Modify: `script-api-train-deepct.py` — fungsi `step` (baris 290-302), `train_one_epoch` (baris 335-349)

**Interfaces:**
- Produces: dict metrik berisi `mae`, `loss`, `psnr`, `ssim`, `mse`, `batches`, `samples`, `balanced_t`.

- [ ] **Step 1: `step` mengembalikan empat angka**

Di `script-api-train-deepct.py`, ganti akhir fungsi `step` (baris 299-302):

```python
            # Windowed to [0,1] because both metrics are defined on that
            # range, while the model works in [-1,1].
            a = (prediction + 1.0) / 2.0
            b = (target + 1.0) / 2.0

            psnr = tf.reduce_mean(tf.image.psnr(a, b, max_val=1.0))
            ssim = tf.reduce_mean(tf.image.ssim(a, b, max_val=1.0))
            mse = tf.reduce_mean(tf.square(prediction - target))

            return loss, psnr, ssim, mse
```

- [ ] **Step 2: Pemanggilnya menampung keempatnya**

Di `train_one_epoch`, ganti `losses, psnrs, batches = [], [], 0` menjadi:

```python
    losses, psnrs, ssims, mses, batches = [], [], [], [], 0
```

dan di dalam loop, ganti:

```python
        loss, psnr, ssim, mse = step(pair, time_scalar, target)

        losses.append(float(loss))
        psnrs.append(float(psnr))
        ssims.append(float(ssim))
        mses.append(float(mse))
        batches += 1
```

- [ ] **Step 3: Dict metrik menyebut keempatnya**

Ganti blok `metrics = {...}` (baris 344-350):

```python
    metrics = {
        # `loss` here is L1 — mean absolute error by definition. It is
        # reported under both names: `mae` because that is what it is, and
        # `loss` because jobs recorded before this change are plotted under
        # that key and would lose their graphs otherwise.
        "mae": round(float(np.mean(losses)), 6),
        "loss": round(float(np.mean(losses)), 6),
        "psnr": round(float(np.mean(psnrs)), 4),
        "ssim": round(float(np.mean(ssims)), 4),
        "mse": round(float(np.mean(mses)), 6),
        "batches": batches,
        "samples": len(samples),
        "balanced_t": balanced_t,
    }
```

- [ ] **Step 4: Periksa sintaksnya**

Run: `python -m py_compile script-api-train-deepct.py`
Expected: tidak ada keluaran.

Ini satu-satunya pemeriksaan yang mungkin di sini — berkas itu butuh TensorFlow dan GPU untuk benar-benar dijalankan, dan keduanya tidak ada di mesin ini.

- [ ] **Step 5: Commit**

```bash
git add script-api-train-deepct.py
git commit -m "Have the trainer compute all four metrics, and name MAE what it is"
```

---

### Task 2: Tabel dan endpoint untuk gambar contoh

**Files:**
- Create: `be/database/migrations/2026_08_23_100001_create_training_samples_table.php`
- Create: `be/app/Models/TrainingSample.php`
- Modify: `be/app/Http/Controllers/API/TrainingWorkerController.php` — metode `sample()`
- Modify: `be/app/Http/Controllers/API/MeTrainingController.php` — `samples()`, `sampleImage()`
- Modify: `be/routes/api.php`
- Test: `be/tests/Feature/TrainingSampleTest.php` (baru)

**Interfaces:**
- Produces: model `TrainingSample` (`training_job_id`, `epoch`, `path`); `POST /api/training/worker/jobs/{id}/sample`; `GET /api/me/training/jobs/{id}/samples`; `GET /api/me/training/jobs/{id}/samples/{epoch}`.

- [ ] **Step 1: Migrasinya**

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One rendered frame per epoch, so a researcher can watch the model improve.
 *
 * The trainer runs the generator on a *fixed* test triplet at the end of every
 * epoch. Fixed matters: comparing epoch 3 against epoch 9 on different
 * triplets says nothing about the model, only about the triplets.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('training_samples', function (Blueprint $table) {
            $table->id();
            $table->foreignId('training_job_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('epoch');
            $table->string('path');
            $table->timestamps();

            // A worker that loses its connection and repeats an epoch is the
            // normal course of events here, so a resend must overwrite rather
            // than accumulate.
            $table->unique(['training_job_id', 'epoch']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('training_samples');
    }
};
```

- [ ] **Step 2: Model**

`be/app/Models/TrainingSample.php`:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

class TrainingSample extends Model
{
    protected $fillable = ['training_job_id', 'epoch', 'path'];

    protected $casts = ['epoch' => 'integer'];

    public function job(): BelongsTo
    {
        return $this->belongsTo(TrainingJob::class, 'training_job_id');
    }

    /**
     * The row cascades with its job; the file on disk does not, because a
     * file is not a row and has no foreign key to follow.
     */
    protected static function booted(): void
    {
        static::deleting(function (self $sample) {
            if ($sample->path && Storage::exists($sample->path)) {
                Storage::delete($sample->path);
            }
        });
    }
}
```

**Catatan penting:** `cascadeOnDelete` di database menghapus barisnya **tanpa**
memanggil event Eloquent, sehingga berkasnya akan tertinggal saat sebuah job
dihapus. Karena itu `TrainingJob` juga butuh event yang menghapus sampelnya
lewat Eloquent lebih dulu — lihat Step 3.

- [ ] **Step 3: `TrainingJob` menghapus sampelnya lewat Eloquent**

Di `be/app/Models/TrainingJob.php`, tambahkan (atau lengkapi bila `booted()`
sudah ada):

```php
    /**
     * Delete samples through Eloquent so their files go too.
     *
     * The foreign key cascades the rows on its own, but a database cascade
     * fires no model events, and the PNGs would sit on disk forever with
     * nothing left pointing at them.
     */
    protected static function booted(): void
    {
        static::deleting(function (self $job) {
            $job->samples()->get()->each->delete();
        });
    }

    public function samples()
    {
        return $this->hasMany(TrainingSample::class);
    }
```

Periksa dulu apakah `booted()` sudah ada di berkas itu; bila ya, tambahkan
closure-nya ke dalam yang ada, jangan menulis metode kedua.

- [ ] **Step 4: Tulis test yang gagal**

`be/tests/Feature/TrainingSampleTest.php`:

```php
<?php

namespace Tests\Feature;

use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\TrainingSample;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * One rendered frame per epoch, so a researcher can watch the model improve.
 */
class TrainingSampleTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;
    private User $stranger;
    private TrainingJob $job;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');

        $this->owner = User::create([
            'name' => 'Owner', 'email' => 'owner@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);

        $this->stranger = User::create([
            'name' => 'Stranger', 'email' => 'stranger@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);

        $dataset = TrainingDataset::create([
            'name' => 'Set', 'source_type' => 'upload',
            'archive_path' => 'training/datasets/x.zip',
            'uploaded_by' => $this->owner->id,
        ]);

        $this->job = TrainingJob::create([
            'name' => 'Run', 'training_dataset_id' => $dataset->id,
            'status' => 'running', 'total_epochs' => 10,
            'created_by' => $this->owner->id,
        ]);
    }

    private function token(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    private function png(int $kilobytes = 8): UploadedFile
    {
        return UploadedFile::fake()->create('sample.png', $kilobytes, 'image/png');
    }

    private function sendSample(int $epoch, ?UploadedFile $file = null)
    {
        return $this->withHeader('X-Training-Worker-Token', config('app.training_worker_token'))
            ->post("/api/training/worker/jobs/{$this->job->id}/sample", [
                'epoch' => $epoch,
                'image' => $file ?? $this->png(),
            ], ['Accept' => 'application/json']);
    }

    public function test_a_worker_can_send_one_sample_per_epoch(): void
    {
        $this->sendSample(3)->assertOk();

        $sample = TrainingSample::firstOrFail();
        $this->assertSame(3, $sample->epoch);
        $this->assertTrue(Storage::exists($sample->path));
    }

    /**
     * A worker that loses its connection and repeats an epoch is the normal
     * course of events here, so the second send replaces the first.
     */
    public function test_resending_an_epoch_replaces_it(): void
    {
        $this->sendSample(3)->assertOk();
        $first = TrainingSample::firstOrFail()->path;

        $this->sendSample(3)->assertOk();

        $this->assertSame(1, TrainingSample::count());
        $this->assertFalse(Storage::exists($first), 'the old file must go');
    }

    public function test_an_oversized_sample_is_refused(): void
    {
        $this->sendSample(3, $this->png(5 * 1024))->assertStatus(422);

        $this->assertSame(0, TrainingSample::count());
    }

    public function test_the_owner_lists_and_reads_its_samples(): void
    {
        $this->sendSample(1)->assertOk();
        $this->sendSample(2)->assertOk();

        $token = $this->token($this->owner);

        $this->apiAs($token)
            ->getJson("/api/me/training/jobs/{$this->job->id}/samples")
            ->assertOk()
            ->assertJsonPath('data.0.epoch', 1)
            ->assertJsonPath('data.1.epoch', 2);

        $this->apiAs($token)
            ->get("/api/me/training/jobs/{$this->job->id}/samples/1")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png');
    }

    public function test_someone_elses_samples_are_not_readable(): void
    {
        $this->sendSample(1)->assertOk();

        $this->apiAs($this->token($this->stranger))
            ->getJson("/api/me/training/jobs/{$this->job->id}/samples")
            ->assertNotFound();
    }

    /**
     * The foreign key cascades the rows on its own, but a database cascade
     * fires no model events — so without help the PNGs stay on disk forever
     * with nothing pointing at them.
     */
    public function test_deleting_a_job_deletes_its_sample_files(): void
    {
        $this->sendSample(1)->assertOk();
        $path = TrainingSample::firstOrFail()->path;

        $this->job->delete();

        $this->assertSame(0, TrainingSample::count());
        $this->assertFalse(Storage::exists($path));
    }
}
```

**Periksa nama header dan config token worker** di
`be/app/Http/Middleware/` (middleware `training.worker`) dan sesuaikan
`sendSample()`; nama di atas adalah dugaan dari nama middleware-nya.

- [ ] **Step 5: Jalankan test, pastikan gagal**

Run: `cd be && php artisan test --filter=TrainingSampleTest`
Expected: FAIL — rutenya belum ada.

- [ ] **Step 6: Endpoint worker**

Di `be/app/Http/Controllers/API/TrainingWorkerController.php`, tambahkan:

```php
    /**
     * POST /api/training/worker/jobs/{id}/sample — one rendered frame.
     *
     * Sent at the end of each epoch, from a fixed test triplet, so scrubbing
     * through them shows the model improving rather than the triplets
     * changing.
     */
    public function sample(Request $request, $id)
    {
        $job = TrainingJob::findOrFail($id);

        $validated = $request->validate([
            'epoch' => 'required|integer|min:0',
            'image' => [
                'required',
                'file',
                // 4 MB, matching the news photo. A sample PNG has no reason to
                // be larger, and without a ceiling a confused worker could
                // fill the disk over a run of hundreds of epochs.
                'max:4096',
                'mimetypes:image/png',
            ],
        ]);

        $existing = TrainingSample::where('training_job_id', $job->id)
            ->where('epoch', $validated['epoch'])
            ->first();

        // Deleted through Eloquent so the old file goes with the row.
        $existing?->delete();

        $path = $request->file('image')->store("training/samples/{$job->id}");

        $sample = TrainingSample::create([
            'training_job_id' => $job->id,
            'epoch' => $validated['epoch'],
            'path' => $path,
        ]);

        return response()->json([
            'success' => true,
            'data' => ['epoch' => $sample->epoch],
        ]);
    }
```

Tambahkan `use App\Models\TrainingSample;` di bagian atas berkas.

- [ ] **Step 7: Endpoint periset**

Di `be/app/Http/Controllers/API/MeTrainingController.php`:

```php
    /** GET /api/me/training/jobs/{id}/samples — which epochs have one. */
    public function samples(Request $request, $id)
    {
        $job = $this->ownedJob($request, $id);

        return response()->json([
            'success' => true,
            'data' => $job->samples()
                ->orderBy('epoch')
                ->get()
                ->map(fn($s) => ['epoch' => $s->epoch])
                ->values(),
        ]);
    }

    /** GET /api/me/training/jobs/{id}/samples/{epoch} — the PNG itself. */
    public function sampleImage(Request $request, $id, $epoch)
    {
        $job = $this->ownedJob($request, $id);

        $sample = $job->samples()->where('epoch', (int) $epoch)->first();

        if (!$sample || !Storage::exists($sample->path)) {
            abort(404);
        }

        return response()->file(Storage::path($sample->path), [
            'Content-Type' => 'image/png',
            // A sample for a given epoch never changes once written.
            'Cache-Control' => 'private, max-age=3600',
        ]);
    }
```

Tambahkan `use Illuminate\Support\Facades\Storage;` bila belum ada.

- [ ] **Step 8: Rute**

Di `be/routes/api.php`, dalam grup `training` milik `me`, setelah `cancel`:

```php
            Route::get('/jobs/{id}/samples', [MeTrainingController::class, 'samples'])->name('api.me.training.samples');
            Route::get('/jobs/{id}/samples/{epoch}', [MeTrainingController::class, 'sampleImage'])->name('api.me.training.samples.show');
```

Dan dalam grup `training.worker`, setelah `checkpoint`:

```php
    Route::post('/jobs/{id}/sample', [TrainingWorkerController::class, 'sample'])->name('api.training.worker.sample');
```

- [ ] **Step 9: Bersihkan cache rute dan jalankan test**

Run: `cd be && php artisan route:clear && php artisan test --filter=TrainingSampleTest`
Expected: PASS, 6 test.

- [ ] **Step 10: Seluruh test backend**

Run: `cd be && php artisan test`
Expected: PASS, 280 test.

- [ ] **Step 11: Commit**

```bash
git add be/database/migrations/2026_08_23_100001_create_training_samples_table.php be/app/Models be/app/Http/Controllers/API be/routes/api.php be/tests/Feature/TrainingSampleTest.php
git commit -m "Keep one rendered frame per training epoch"
```

---

### Task 3: Trainer mengirim gambar contoh

**Files:**
- Modify: `script-api-train-deepct.py` — `train_one_epoch`, dan fungsi baru `send_sample`

**Interfaces:**
- Consumes: `POST /api/training/worker/jobs/{id}/sample` dari Task 2.

- [ ] **Step 1: Render satu triplet tetap**

Tambahkan ke `script-api-train-deepct.py`, di dekat `save_generator`:

```python
def render_sample(generator, paths, samples):
    """One PNG from a fixed triplet, so epochs are comparable.

    The triplet is picked by a fixed index rather than at random: comparing
    epoch 3 against epoch 9 on different triplets says nothing about the
    model, only about the triplets.
    """
    if not samples:
        return None

    pair, time_scalar, _ = batch_from(paths, samples, [len(samples) // 2])
    prediction = generator([pair, time_scalar], training=False)

    # Back to [0,255] from the model's [-1,1].
    frame = ((prediction[0].numpy() + 1.0) / 2.0 * 255.0).clip(0, 255).astype("uint8")

    if frame.ndim == 3 and frame.shape[-1] == 1:
        frame = frame[:, :, 0]

    buffer = io.BytesIO()
    Image.fromarray(frame).save(buffer, format="PNG")
    return buffer.getvalue()


def send_sample(request: TrainRequest, epoch: int, png: bytes):
    """Best-effort: a missing sample must never fail a run."""
    if not png:
        return

    try:
        requests.post(
            f"{request.callback_url}/jobs/{request.job_id}/sample",
            headers={"X-Training-Worker-Token": request.worker_token},
            data={"epoch": str(epoch)},
            files={"image": ("sample.png", png, "image/png")},
            timeout=60,
        )
    except Exception as error:
        print(f"[epoch {epoch}] sample upload failed, continuing: {error}")
```

**Baca berkasnya lebih dulu** untuk nama sebenarnya dari `request.callback_url`
dan `request.worker_token` — keduanya diambil dari `TrainRequest` di baris 179
dan namanya mungkin berbeda. Pastikan juga `io`, `requests` dan `PIL.Image`
sudah diimpor; tambahkan bila belum.

- [ ] **Step 2: Panggil di akhir tiap epoch**

Di `train_one_epoch`, tepat sebelum `return written, metrics`:

```python
    send_sample(request, epoch, render_sample(generator, paths, samples))
```

- [ ] **Step 3: Periksa sintaksnya**

Run: `python -m py_compile script-api-train-deepct.py`
Expected: tidak ada keluaran.

- [ ] **Step 4: Commit**

```bash
git add script-api-train-deepct.py
git commit -m "Send one rendered frame per epoch from a fixed triplet"
```

---

### Task 4: Tab Training admin dihapus, kemampuannya pindah

**Files:**
- Delete: `fe/lib/screens/admin/training_screen.dart`
- Modify: `fe/lib/screens/admin/admin_shell.dart:17,27,115-116`
- Modify: `fe/lib/screens/admin/model_management_screen.dart` — bagian training
- Modify: `fe/lib/services/training_service.dart` — buang `dispatch`
- Modify: `be/app/Http/Controllers/API/TrainingController.php:197` — hapus `dispatchJob`
- Modify: `be/routes/api.php:176` — hapus rutenya
- Modify: `be/tests/Feature/TrainingTest.php` — hapus test dispatch

**Interfaces:**
- Consumes: `POST /admin/training/jobs/{id}/register-model`, `DELETE /admin/training/jobs/{id}`, `DELETE /admin/training/datasets/{id}` — semuanya sudah ada dan tidak berubah.
- Produces: `POST /admin/training/jobs/{id}/dispatch` **tidak ada lagi**.

- [ ] **Step 1: Cabut `dispatch` di backend**

Hapus baris 176 di `be/routes/api.php`, dan hapus seluruh metode
`dispatchJob()` di `be/app/Http/Controllers/API/TrainingController.php:197`.

Bila `TrainerDispatcher` jadi tidak terpakai di controller itu, buang
import-nya — periksa dulu, `storeDataset` atau yang lain mungkin memakainya.

- [ ] **Step 2: Buang test dispatch**

Run: `cd be && grep -n "dispatch" tests/Feature/TrainingTest.php`

Hapus test yang menguji rute itu. Jangan menggantinya dengan test tentang
`claim`: itu perilaku yang berbeda, sudah punya testnya sendiri, dan
menambahkan asersi di tempat yang salah menyembunyikan cakupan yang hilang
alih-alih menutupnya.

Catat berapa test yang dihapus — angkanya dipakai di Step 8.

- [ ] **Step 3: Buang `dispatch` dari layanan Flutter**

Run: `cd fe && grep -n "dispatch" lib/services/training_service.dart`

Hapus metodenya.

- [ ] **Step 4: Hapus tab admin**

Hapus berkas `fe/lib/screens/admin/training_screen.dart`.

Di `fe/lib/screens/admin/admin_shell.dart`: hapus `import 'training_screen.dart';`
(baris 17), entri `training(...)` di enum `AdminSection` (baris 27), dan cabang
`case AdminSection.training:` (baris 115-116).

Periksa `_openLink()` di berkas yang sama — bila ia memetakan sebuah link ke
`AdminSection.training`, hapus cabang itu juga.

- [ ] **Step 5: Model Management mendapat bagian training**

Di `fe/lib/screens/admin/model_management_screen.dart`, tambahkan sebuah bagian
di bawah daftar model:

```dart
  /// Finished training runs whose weights are not a model yet.
  ///
  /// This lives here rather than on a screen of its own because registering
  /// weights *is* creating a model version, and models live here. It was the
  /// one thing the deleted Training tab could do that nothing else could.
  Widget _buildTrainingHandoff(BuildContext context) {
    if (_finishedJobs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          'Training runs ready to register',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final job in _finishedJobs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.name),
                      Text(
                        '${job.currentEpoch} epochs',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _registerModel(job),
                  child: const Text('REGISTER AS MODEL'),
                ),
                TextButton(
                  onPressed: () => _deleteJob(job),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.error,
                  ),
                  child: const Text('DELETE'),
                ),
              ],
            ),
          ),
      ],
    );
  }
```

**Salin `_registerModel` dan `_deleteJob` dari `admin/training_screen.dart`
baris 227 dan 217 sebelum menghapus berkasnya** — keduanya sudah bekerja dan
menulis ulangnya hanya menambah risiko. Bawa juga `TrainingService` yang mereka
pakai, dan muat `_finishedJobs` di `_load()` dengan
`TrainingService.jobs(status: 'completed')`.

Penghapusan dataset ikut pindah dengan cara yang sama, dari `_deleteDataset`
baris 133.

- [ ] **Step 6: Layar periset bisa membatalkan job sendiri**

Di `fe/lib/screens/user/training_screen.dart`, tambahkan tombol batal pada job
yang statusnya `queued`, `claimed` atau `running`, memanggil
`ResearcherTrainingService.cancel(id)` yang sudah ada.

- [ ] **Step 7: Analisa dan test Flutter**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih. Bila ada test yang menyebut `admin/training_screen.dart`,
hapus atau sesuaikan.

- [ ] **Step 8: Seluruh test backend**

Run: `cd be && php artisan test`
Expected: PASS, 280 dikurangi jumlah test dispatch yang dihapus di Step 2.

- [ ] **Step 9: Commit**

```bash
git add be fe
git commit -m "Delete the admin training tab, and move what only it could do"
```

---

### Task 5: Layar periset menampilkan metrik dan contoh

**Files:**
- Modify: `fe/lib/models/training.dart` — parsing metrik
- Modify: `fe/lib/services/researcher_training_service.dart` — `samples`, `sampleImage`
- Modify: `fe/lib/screens/user/training_screen.dart` — tabel metrik, tombol contoh, unggah `bundleFrames`
- Test: `fe/test/training_metrics_test.dart` (baru)

**Interfaces:**
- Consumes: `GET /me/training/jobs/{id}/samples` dan `.../samples/{epoch}` dari Task 2; `bundleFrames` dan `FrameStackViewer` dari bagian C.
- Produces: `String metricLabel(Map<String, dynamic> metrics, String key)`.

- [ ] **Step 1: Tulis test yang gagal**

`fe/test/training_metrics_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/training.dart';

void main() {
  test('a metric that was measured is shown', () {
    expect(metricLabel(const {'psnr': 31.4159}, 'psnr'), '31.4159');
  });

  test('a metric that is missing reads as absent, not as zero', () {
    // Runs from before the trainer computed SSIM have only two of the four.
    // Showing 0 would read as a measurement, and a very bad one.
    expect(metricLabel(const {'psnr': 31.4}, 'ssim'), '—');
    expect(metricLabel(const {}, 'mae'), '—');
  });

  test('mae falls back to loss, because they are the same number', () {
    // The trainer's loss is tf.reduce_mean(tf.abs(...)) — MAE by definition.
    // Older runs recorded it only under `loss`.
    expect(metricLabel(const {'loss': 0.0123}, 'mae'), '0.0123');
  });

  test('an explicit mae wins over loss', () {
    expect(metricLabel(const {'mae': 0.01, 'loss': 0.99}, 'mae'), '0.01');
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/training_metrics_test.dart`
Expected: FAIL — `metricLabel` belum ada.

- [ ] **Step 3: Tulis `metricLabel`**

Di `fe/lib/models/training.dart`, sebagai fungsi tingkat atas:

```dart
/// One metric, formatted for a table cell.
///
/// Returns an em dash rather than `0` when the value is absent: runs recorded
/// before the trainer computed SSIM and MSE have only two of the four, and a
/// zero would read as a measurement instead of a gap.
String metricLabel(Map<String, dynamic> metrics, String key) {
  // The trainer's `loss` is tf.reduce_mean(tf.abs(prediction - target)) —
  // mean absolute error by definition. Newer runs send both names; older ones
  // sent only `loss`.
  final value = metrics[key] ?? (key == 'mae' ? metrics['loss'] : null);

  if (value == null) return '—';
  if (value is num) return '${value == value.roundToDouble() && value.abs() < 1e15 ? value : value}';

  return value.toString();
}
```

Sederhanakan cabang `num` bila `flutter analyze` mengeluh; yang penting adalah
`—` untuk null dan angka apa adanya untuk yang ada.

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/training_metrics_test.dart`
Expected: PASS, 4 test.

- [ ] **Step 5: Layanan mengambil daftar contoh**

Di `fe/lib/services/researcher_training_service.dart`:

```dart
  /// GET /me/training/jobs/{id}/samples — which epochs produced a frame.
  Future<List<int>> samples(int id) async {
    final body = await _api.get('${ApiConfig.meTrainingJobs}/$id/samples');

    return (body['data'] as List? ?? [])
        .map((e) => ((e as Map)['epoch'] as num).toInt())
        .toList();
  }

  /// GET /me/training/jobs/{id}/samples/{epoch} — the PNG itself.
  Future<Uint8List> sampleImage(int id, int epoch) async {
    final result = await _api.getBytes(
      '${ApiConfig.meTrainingJobs}/$id/samples/$epoch',
    );

    return result.bytes;
  }
```

Periksa nama `_api.getBytes` di `api_client.dart` dan konstanta
`ApiConfig.meTrainingJobs`; keduanya diambil dari pembacaan sebelumnya.

- [ ] **Step 6: Tabel metrik di layar**

Di `fe/lib/screens/user/training_screen.dart`, pada detail sebuah job,
tampilkan tabel per-epoch dari `TrainingMetric` yang sudah dikembalikan
`show`:

```dart
              DataTable(
                columns: const [
                  DataColumn(label: Text('Epoch')),
                  DataColumn(label: Text('MAE')),
                  DataColumn(label: Text('MSE')),
                  DataColumn(label: Text('PSNR')),
                  DataColumn(label: Text('SSIM')),
                ],
                rows: [
                  for (final m in metrics)
                    DataRow(
                      cells: [
                        DataCell(Text('${m.epoch}')),
                        DataCell(Text(metricLabel(m.metrics, 'mae'))),
                        DataCell(Text(metricLabel(m.metrics, 'mse'))),
                        DataCell(Text(metricLabel(m.metrics, 'psnr'))),
                        DataCell(Text(metricLabel(m.metrics, 'ssim'))),
                      ],
                    ),
                ],
              ),
```

Bungkus dengan `SingleChildScrollView(scrollDirection: Axis.horizontal)` —
lima kolom tidak muat di ponsel, dan `DataTable` meluap alih-alih menggulung.

- [ ] **Step 7: Tombol contoh membuka `FrameStackViewer`**

```dart
  Future<void> _openSamples(TrainingJob job) async {
    final epochs = await _service.samples(job.id);
    if (!mounted || epochs.isEmpty) return;

    // FrameStackViewer takes PredictionFrame, and reusing it beats a twin type
    // that differs by one field. This is the only place in the project where a
    // PredictionFrame is not a prediction frame — the axis here is the epoch.
    final frames = [
      for (final e in epochs)
        PredictionFrame(name: 'Epoch $e', kind: 'output', size: 0),
    ];

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FrameStackViewer(
          frames: frames,
          initialIndex: frames.length - 1,
          loader: (name) => _service.sampleImage(
            job.id,
            int.parse(name.split(' ').last),
          ),
        ),
      ),
    );
  }
```

`initialIndex` adalah epoch **terakhir**: yang ingin dilihat orang pertama kali
adalah keadaan model sekarang, bukan seperti apa ia di awal.

- [ ] **Step 8: Unggah dataset menerima beberapa `.tif`**

Terapkan pola yang sama seperti `upload_screen.dart` di bagian C: `FilePicker`
dengan `allowMultiple: true` dan `FileType.any`, satu `.zip` dikirim apa adanya,
beberapa `.tif` dibungkus dengan `bundleFrames`, campuran ditolak.

- [ ] **Step 9: Analisa dan seluruh test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 166 test lulus.

- [ ] **Step 10: Bangun APK**

Run: `cd fe && flutter build apk --release`
Expected: berhasil.

- [ ] **Step 11: Commit**

```bash
git add fe
git commit -m "Show four metrics per epoch, and let the samples be scrubbed"
```

---

### Task 6: Catat, dan katakan apa yang belum terbukti

**Files:**
- Modify: `API.md`, `ARCHITECTURE.md`, `AI_EXPERIMENTS.md`, `CHANGELOG.md`, `ROADMAP.md`

- [ ] **Step 1: Verifikasi penuh**

```bash
cd be && php artisan test
cd ../fe && flutter analyze
flutter test
flutter build apk --release
```

- [ ] **Step 2: `API.md`**

Tiga endpoint sampel baru, dan `POST /admin/training/jobs/{id}/dispatch`
**dihapus** dari tabel dengan satu kalimat kenapa.

- [ ] **Step 3: `ARCHITECTURE.md`**

Tabel `training_samples` di daftar tabel. Perbarui §7 supaya menyebut bahwa job
antre diklaim worker dan tidak ada lagi dorongan manual.

- [ ] **Step 4: `AI_EXPERIMENTS.md`**

Berkas itu adalah jurnal riset model. Catat bahwa trainer kini melaporkan MAE,
MSE, PSNR dan SSIM per epoch, bahwa `loss` dan `mae` adalah angka yang sama,
dan bahwa satu gambar contoh dari triplet tetap direkam tiap epoch.

- [ ] **Step 5: `CHANGELOG.md`**

Sebutkan **mengapa** tab admin dihapus tanpa kemampuannya hilang, dan bahwa
MAE ternyata sudah dihitung sejak awal dengan nama `loss`.

- [ ] **Step 6: `ROADMAP.md`**

**Jangan centang D.** Tandai kodenya selesai dan sebutkan bahwa jalur training
belum pernah dijalankan sekali pun terhadap GPU sungguhan — sekarang dengan
tiga hal baru di atasnya. Sebutkan juga apa yang dibutuhkan untuk
membuktikannya: sesi Kaggle dengan `script-api-train-deepct.py` versi baru, dan
training yang berjalan sampai selesai.

- [ ] **Step 7: Commit**

```bash
git add API.md ARCHITECTURE.md AI_EXPERIMENTS.md CHANGELOG.md ROADMAP.md
git commit -m "Record part D, and that none of it has met a GPU yet"
```

---

## Catatan untuk pelaksana

**Task 1 dan 3 tidak bisa diuji di sini.** `script-api-train-deepct.py` butuh
TensorFlow dan GPU. `python -m py_compile` adalah satu-satunya pemeriksaan yang
mungkin, dan ia hanya membuktikan berkasnya terurai — bukan bahwa
`tf.image.ssim` dipanggil dengan benar.

**Task 4 menghapus sebuah berkas 1133 baris.** Salin `_registerModel`,
`_deleteJob` dan `_deleteDataset` **sebelum** menghapusnya. Ketiganya sudah
bekerja; menulis ulangnya hanya menambah risiko pada satu-satunya jalan keluar
dari pipeline training.

**Empat tempat rencana ini menyuruh membaca dulu:** nama header token worker
(Task 2 Step 4), nama `request.callback_url` dan `request.worker_token` di
`TrainRequest` (Task 3 Step 1), nama `_api.getBytes` dan
`ApiConfig.meTrainingJobs` (Task 5 Step 5), dan apakah `TrainingJob` sudah
punya `booted()` (Task 2 Step 3).

**D akan selesai tanpa terbukti.** Itu bukan kegagalan rencana ini; itu
keadaan yang sudah dicatat ROADMAP §10 sejak 18 Agustus, dan D menambahkan
lebih banyak di atasnya. Task 6 Step 6 mengharuskan itu dikatakan, bukan
disamarkan dengan centang.
