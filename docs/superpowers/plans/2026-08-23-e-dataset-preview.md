# Bagian E — Preview dataset training: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Periset bisa menggeser frame dataset yang baru diunggah, sebelum sebuah worker mengambil pekerjaannya.

**Architecture:** Dua endpoint membaca entri langsung dari dalam arsip ZIP lewat `ZipArchive`, dirender oleh `TiffPreview` yang sudah ada, dan di-cache sebagai PNG di samping arsipnya. Tidak ada status baru, tidak ada ekstraksi, tidak ada byte disk tambahan untuk arsipnya.

**Tech Stack:** Laravel 12 + Octane/RoadRunner, Flutter, `ZipArchive`, `TiffPreview`.

## Global Constraints

- **Tidak ada status baru dan tidak ada pemecahan alur.** Job duduk sebagai `queued` sampai diklaim worker; jendela untuk melihat sudah ada.
- **Arsip tidak diekstrak.** `ZipArchive::getFromName()` membaca satu entri; sebuah dataset 2 GB tidak boleh digandakan hanya untuk dilihat.
- **Nama entri divalidasi terhadap daftar isi arsip**, bukan dipakai apa adanya — `../../.env` yang lolos ke `getFromName()` akan membaca berkas di luar arsip.
- **Cache PNG mengikuti pola prediksi:** `{dir}/preview/{size}_{name}.png`, `Storage::exists` dulu, render kalau tidak ada.
- **Frame dataset ber-`kind: 'input'`** — tidak ada yang dihasilkan model, jadi tick di slider kosong dan itu benar.
- **`php artisan route:clear`** setelah menambah rute (CLAUDE.md).
- **Dasar sebelum E:** backend 272 test, Flutter 168 test, `flutter analyze` bersih.

---

### Task 1: Membaca frame dari dalam arsip

**Files:**
- Modify: `be/app/Http/Controllers/API/MeTrainingController.php`
- Modify: `be/routes/api.php`
- Test: `be/tests/Feature/TrainingDatasetPreviewTest.php` (baru)

**Interfaces:**
- Produces: `GET /api/me/training/jobs/{id}/dataset/frames` menjawab `{success, data: [{name, size}]}`; `GET /api/me/training/jobs/{id}/dataset/frames/{name}/preview` menjawab PNG.

- [ ] **Step 1: Tulis test yang gagal**

`be/tests/Feature/TrainingDatasetPreviewTest.php`:

```php
<?php

namespace Tests\Feature;

use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;
use ZipArchive;

/**
 * Looking at a dataset before a GPU spends hours on it.
 *
 * The archive is never extracted: a dataset is the largest thing this platform
 * stores, and doubling it on disk just to look would be absurd. ZipArchive
 * reads one entry at a time instead.
 */
class TrainingDatasetPreviewTest extends TestCase
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

        $archive = 'training/datasets/set.zip';
        Storage::put($archive, '');
        $this->writeArchive(Storage::path($archive));

        $dataset = TrainingDataset::create([
            'name' => 'Set', 'source_type' => 'upload',
            'archive_path' => $archive,
            'uploaded_by' => $this->owner->id,
        ]);

        $this->job = TrainingJob::create([
            'name' => 'Run', 'training_dataset_id' => $dataset->id,
            'status' => 'queued', 'total_epochs' => 5,
            'created_by' => $this->owner->id,
        ]);
    }

    /**
     * A 4x4 16-bit greyscale TIFF, little-endian — the same shape
     * TiffPreviewTest builds, so the renderer is exercised on something it
     * genuinely understands rather than on random bytes.
     */
    private function tif(): string
    {
        $width = 4;
        $height = 4;
        $pixels = pack('v*', ...array_fill(0, $width * $height, 30000));

        $header = "II\x2a\x00" . pack('V', 8);
        $entries = [
            [256, 3, 1, $width],
            [257, 3, 1, $height],
            [258, 3, 1, 16],
            [259, 3, 1, 1],
            [262, 3, 1, 1],
            [273, 4, 1, 8 + 2 + (12 * 8) + 4],
            [277, 3, 1, 1],
            [279, 4, 1, strlen($pixels)],
        ];

        $ifd = pack('v', count($entries));
        foreach ($entries as [$tag, $type, $count, $value]) {
            $ifd .= pack('vvV', $tag, $type, $count);
            $ifd .= $type === 3 ? pack('vv', $value, 0) : pack('V', $value);
        }
        $ifd .= pack('V', 0);

        return $header . $ifd . $pixels;
    }

    private function writeArchive(string $absolute): void
    {
        $zip = new ZipArchive();
        $zip->open($absolute, ZipArchive::OVERWRITE | ZipArchive::CREATE);
        $zip->addFromString('frame_001.tif', $this->tif());
        $zip->addFromString('frame_002.tif', $this->tif());
        $zip->addFromString('notes.txt', 'not a frame');
        $zip->close();
    }

    private function token(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    public function test_the_frames_inside_the_archive_are_listed(): void
    {
        $this->apiAs($this->token($this->owner))
            ->getJson("/api/me/training/jobs/{$this->job->id}/dataset/frames")
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.name', 'frame_001.tif')
            ->assertJsonPath('data.1.name', 'frame_002.tif');
    }

    /** A README in the archive is not a frame and must not be offered. */
    public function test_a_non_frame_entry_is_not_listed(): void
    {
        $response = $this->apiAs($this->token($this->owner))
            ->getJson("/api/me/training/jobs/{$this->job->id}/dataset/frames")
            ->assertOk();

        $this->assertStringNotContainsString('notes.txt', $response->getContent());
    }

    public function test_a_frame_renders_as_a_png(): void
    {
        $this->apiAs($this->token($this->owner))
            ->get("/api/me/training/jobs/{$this->job->id}/dataset/frames/frame_001.tif/preview")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png');
    }

    /**
     * The name has to be checked against the archive's own listing. A name
     * that reaches getFromName() unchecked reads whatever it points at.
     */
    public function test_a_name_outside_the_archive_is_refused(): void
    {
        $this->apiAs($this->token($this->owner))
            ->get("/api/me/training/jobs/{$this->job->id}/dataset/frames/"
                . urlencode('../../.env') . '/preview')
            ->assertNotFound();
    }

    public function test_an_unknown_frame_is_refused(): void
    {
        $this->apiAs($this->token($this->owner))
            ->get("/api/me/training/jobs/{$this->job->id}/dataset/frames/frame_999.tif/preview")
            ->assertNotFound();
    }

    public function test_someone_elses_dataset_is_not_readable(): void
    {
        $this->apiAs($this->token($this->stranger))
            ->getJson("/api/me/training/jobs/{$this->job->id}/dataset/frames")
            ->assertNotFound();
    }

    /** The second read comes from the cache, not from the archive again. */
    public function test_a_rendered_frame_is_cached(): void
    {
        $token = $this->token($this->owner);
        $url = "/api/me/training/jobs/{$this->job->id}/dataset/frames/frame_001.tif/preview";

        $this->apiAs($token)->get($url)->assertOk();

        $cached = collect(Storage::allFiles('training/datasets/preview'))
            ->filter(fn($p) => str_ends_with($p, '.png'));

        $this->assertCount(1, $cached, 'the render should have been kept');

        $this->apiAs($token)->get($url)->assertOk();
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd be && php artisan test --filter=TrainingDatasetPreviewTest`
Expected: FAIL, rutenya belum ada.

- [ ] **Step 3: Tulis kedua endpoint**

Di `be/app/Http/Controllers/API/MeTrainingController.php`, tambahkan sebelum
`ownedJob()`:

```php
    /**
     * GET /api/me/training/jobs/{id}/dataset/frames
     *
     * Read from inside the archive rather than extracting it. A dataset is the
     * largest thing this platform stores, and doubling it on disk to look at
     * it would be absurd — ZipArchive reads the central directory at the end
     * of the file, so listing costs the entry count and not the size.
     */
    public function datasetFrames(Request $request, $id)
    {
        $job = $this->ownedJob($request, $id);

        return response()->json([
            'success' => true,
            'data' => $this->archiveFrames($job)
                ->map(fn($entry) => [
                    'name' => $entry['name'],
                    'size' => $entry['size'],
                ])
                ->values(),
        ]);
    }

    /**
     * GET /api/me/training/jobs/{id}/dataset/frames/{name}/preview
     *
     * The frames are 16-bit TIFFs, which neither a browser nor Flutter can
     * decode, so TiffPreview renders them here — the same path a prediction
     * frame takes.
     */
    public function datasetFramePreview(Request $request, $id, string $name, TiffPreview $preview)
    {
        $job = $this->ownedJob($request, $id);

        $size = (int) $request->input('size', 512);
        $size = max(64, min($size, 2048));

        // Checked against the archive's own listing rather than sanitised.
        // A name that reaches getFromName() unchecked reads whatever it points
        // at, and basename() alone would still accept an entry this dataset
        // does not have.
        $known = $this->archiveFrames($job)->firstWhere('name', $name);

        if ($known === null) {
            abort(404);
        }

        $cachePath = "training/datasets/preview/{$job->training_dataset_id}/{$size}_{$name}.png";

        if (!Storage::exists($cachePath)) {
            $zip = new ZipArchive();

            if ($zip->open(Storage::path($job->dataset->archive_path)) !== true) {
                abort(404);
            }

            $tiff = $zip->getFromName($name);
            $zip->close();

            if ($tiff === false) {
                abort(404);
            }

            Storage::put($cachePath, $preview->toPng($tiff, $size));
        }

        return response()->file(Storage::path($cachePath), [
            'Content-Type' => 'image/png',
            // An entry inside an archive never changes.
            'Cache-Control' => 'private, max-age=3600',
        ]);
    }

    /**
     * The `.tif` entries in a job's dataset archive, sorted by name.
     *
     * Sorted because the numbering in the names is the sequence — the same
     * thing the trainer builds its triples from.
     */
    private function archiveFrames(TrainingJob $job)
    {
        $path = $job->dataset?->archive_path;

        if (!$path || !Storage::exists($path)) {
            return collect();
        }

        $zip = new ZipArchive();

        if ($zip->open(Storage::path($path)) !== true) {
            return collect();
        }

        $entries = collect();

        for ($i = 0; $i < $zip->numFiles; $i++) {
            $stat = $zip->statIndex($i);
            $name = $stat['name'];

            // Folder entries, and anything a researcher zipped in beside the
            // frames — a README is not a frame.
            if (str_ends_with($name, '/')) {
                continue;
            }

            $lower = strtolower($name);
            if (!str_ends_with($lower, '.tif') && !str_ends_with($lower, '.tiff')) {
                continue;
            }

            $entries->push(['name' => $name, 'size' => $stat['size']]);
        }

        $zip->close();

        return $entries->sortBy('name')->values();
    }
```

Tambahkan di bagian atas berkas, bila belum ada:

```php
use App\Services\TiffPreview;
use ZipArchive;
```

`Storage` dan `TrainingJob` sudah diimpor di sana dari bagian D — periksa.

- [ ] **Step 4: Rute**

Di `be/routes/api.php`, dalam grup `training` milik `me`, setelah rute
`samples`:

```php
            Route::get('/jobs/{id}/dataset/frames', [MeTrainingController::class, 'datasetFrames'])->name('api.me.training.dataset.frames');
            Route::get('/jobs/{id}/dataset/frames/{name}/preview', [MeTrainingController::class, 'datasetFramePreview'])->name('api.me.training.dataset.preview');
```

- [ ] **Step 5: Bersihkan cache rute dan jalankan test**

Run: `cd be && php artisan route:clear && php artisan test --filter=TrainingDatasetPreviewTest`
Expected: PASS, 7 test.

Bila `test_a_frame_renders_as_a_png` gagal karena `TiffPreview` menolak TIFF
buatan test, **jangan longgarkan renderernya** — bandingkan dengan
`be/tests/Unit/TiffPreviewTest.php`, yang sudah membangun TIFF yang ia terima,
dan pakai bentuk yang sama.

- [ ] **Step 6: Seluruh test backend**

Run: `cd be && php artisan test`
Expected: PASS, 279 test.

- [ ] **Step 7: Commit**

```bash
git add be/app/Http/Controllers/API/MeTrainingController.php be/routes/api.php be/tests/Feature/TrainingDatasetPreviewTest.php
git commit -m "Read dataset frames from inside the archive"
```

---

### Task 2: Tombol preview dataset

**Files:**
- Modify: `fe/lib/services/researcher_training_service.dart`
- Modify: `fe/lib/screens/user/training_screen.dart`

**Interfaces:**
- Consumes: kedua endpoint dari Task 1.
- Produces: `ResearcherTrainingService.datasetFrames(int id)` mengembalikan `Future<List<PredictionFrame>>`; `datasetFramePreview(int id, String name)` mengembalikan `Future<Uint8List>`.

- [ ] **Step 1: Layanan**

Di `fe/lib/services/researcher_training_service.dart`, di samping `samples`:

```dart
  /// GET /me/training/jobs/{id}/dataset/frames
  ///
  /// Mapped to PredictionFrame with `kind: 'input'` — nothing here was
  /// generated by a model, so the ticks on the viewer's slider stay empty,
  /// which is correct rather than a gap.
  Future<List<PredictionFrame>> datasetFrames(int id) async {
    final body = await _api.get(
      '${ApiConfig.meTrainingJobs}/$id/dataset/frames',
    );

    return (body['data'] as List? ?? const [])
        .map(
          (e) => PredictionFrame(
            name: (e as Map)['name'].toString(),
            kind: 'input',
            size: (e['size'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  /// GET /me/training/jobs/{id}/dataset/frames/{name}/preview
  Future<Uint8List> datasetFramePreview(int id, String name) async {
    final result = await _api.getBytes(
      '${ApiConfig.meTrainingJobs}/$id/dataset/frames/'
      '${Uri.encodeComponent(name)}/preview',
    );

    return result.bytes;
  }
```

Tambahkan `import '../models/prediction_frame.dart';`.

- [ ] **Step 2: Tombol di layar**

Di `fe/lib/screens/user/training_screen.dart`, ganti `_sampleButton` sehingga
ia menampilkan **dua** tombol berdampingan:

```dart
  Widget _sampleButton(TrainingRun run) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _openDataset(run),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('PREVIEW DATASET'),
        ),
        OutlinedButton.icon(
          onPressed: () => _openSamples(run),
          icon: const Icon(Icons.image_outlined, size: 18),
          label: const Text('VIEW EPOCH FRAMES'),
        ),
      ],
    ),
  );

  /// The frames going in, before a GPU spends hours on them.
  Future<void> _openDataset(TrainingRun run) async {
    List<PredictionFrame> frames;

    try {
      frames = await _service.datasetFrames(run.id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }

    if (!mounted) return;

    if (frames.isEmpty) {
      setState(
        () => _error = 'No .tif frames were found inside that archive.',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FrameStackViewer(
          frames: frames,
          initialIndex: 0,
          loader: (name) => _service.datasetFramePreview(run.id, name),
        ),
      ),
    );
  }
```

`Wrap` dan bukan `Row`: dua tombol berlabel penuh tidak muat berdampingan pada
lebar ponsel, dan `Row` akan meluap alih-alih membungkus.

- [ ] **Step 3: Analisa dan test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 168 test lulus. Tidak ada test baru di sisi Flutter:
yang ditambahkan adalah pemanggilan, dan perilakunya sudah dijamin test bagian
C untuk `FrameStackViewer`.

- [ ] **Step 4: Commit**

```bash
git add fe/lib
git commit -m "Let a researcher look at a dataset before training on it"
```

---

### Task 3: Catat

**Files:**
- Modify: `API.md`, `CHANGELOG.md`, `ROADMAP.md`

- [ ] **Step 1: Verifikasi penuh**

```bash
cd be && php artisan test
cd ../fe && flutter analyze && flutter test
```

- [ ] **Step 2: `API.md`**

Kedua endpoint dataset, dengan catatan bahwa arsipnya tidak diekstrak dan
namanya divalidasi terhadap daftar isi arsip.

- [ ] **Step 3: `CHANGELOG.md`**

Sebutkan bahwa ini menutup separuh poin 10 yang terlewat saat D dirancang,
bukan permintaan baru — dan bahwa audit terhadap sepuluh permintaan asli yang
menemukannya.

- [ ] **Step 4: `ROADMAP.md`**

Centang E bila kedua suite hijau. Berbeda dari C dan D, E tidak menuntut GPU:
ia membaca berkas yang sudah ada di disk, dan test membuktikannya. Yang tetap
disebut: preview-nya belum dilihat mata di perangkat.

- [ ] **Step 5: Commit**

```bash
git add API.md CHANGELOG.md ROADMAP.md
git commit -m "Record part E"
```

---

## Catatan untuk pelaksana

**Dua tempat rencana ini menyuruh membaca dulu:** apakah `Storage` dan
`TrainingJob` sudah diimpor di `MeTrainingController` (Task 1 Step 3), dan
bentuk TIFF yang `TiffPreview` benar-benar terima, di
`be/tests/Unit/TiffPreviewTest.php` (Task 1 Step 5).

**E adalah satu-satunya bagian sejak C yang bisa selesai penuh tanpa GPU.** Ia
membaca berkas yang sudah ada dan merender dengan kode yang sudah diuji.
