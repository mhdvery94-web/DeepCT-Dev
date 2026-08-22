# Bagian C — Penelusur frame dan unggah dua langkah: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Periset mengunggah berkas, menggeser frame-nya seperti di ImageJ, lalu memutuskan menjalankan analisis — dan melihat hasilnya dengan penelusur yang sama, kali ini dengan frame sisipan model ditandai.

**Architecture:** Status `uploaded` disisipkan di depan `pending` sehingga sebuah unggahan bisa ada tanpa antre, dan `POST /predictions/{id}/start` yang mengantrikannya. Penelusur yang sudah ada diangkat jadi widget publik dan diberi slider, tick, dan badge. Preview di kedua tempat memakai endpoint yang sudah ada — tidak ada endpoint preview baru.

**Tech Stack:** Laravel 12 + Octane/RoadRunner, Flutter, MySQL, paket `archive`.

## Global Constraints

- **Status baru `uploaded` disisipkan DI DEPAN `pending`**, bukan di belakang: `['uploaded', 'pending', 'processing', 'completed', 'failed']`.
- **Tidak ada endpoint preview baru.** `GET /predictions/{id}/frames` dan `.../frames/{name}/preview` sudah ada dan sudah dipakai.
- **Tidak ada dekoder TIFF di Dart.** `TiffPreview.php` tetap satu-satunya; memportingnya menghasilkan dua dekoder yang bisa berbeda tanpa ada yang tahu.
- **`file_picker` tetap `^11.0.0`** dan **jangan pernah `FileType.custom`** — pakai `FileType.any`, periksa nama dengan `hasExtension` di `lib/utils/file_extension.dart`. Alasannya di CLAUDE.md.
- **Nama berkas `.tif` tidak diubah saat dibungkus.** Penomoran di nama itulah yang memberi tahu backend di mana celahnya.
- **Bahasa antarmuka Inggris**, termasuk pesan kegagalan.
- **Sudut kotak** (`BorderRadius.zero`), `withValues(alpha:)` bukan `withOpacity`.
- **Octane tidak bisa restart sendiri di Windows** — `npm run octane:reset`. Dan **`php artisan route:clear`** setelah menambah rute, atau rute barunya tidak akan terlihat di mana pun (CLAUDE.md).
- **Dasar sebelum C:** backend 270 test, Flutter 153 test, `flutter analyze` bersih.
- **Perangkat `SM A325F` tersambung.** Pemeriksaan mata dikerjakan di sana, bukan ditunda.

---

### Task 1: Status `uploaded`, dan endpoint yang mengantrikan

**Files:**
- Create: `be/database/migrations/2026_08_23_090001_add_uploaded_status_to_analysis_records.php`
- Modify: `be/app/Services/PredictionIntake.php:72,77`
- Modify: `be/app/Http/Controllers/API/AnalysisController.php` — metode `start()` baru
- Modify: `be/routes/api.php`
- Test: `be/tests/Feature/PredictionStartTest.php` (baru)

**Interfaces:**
- Produces: enum `analysis_records.status` menerima `'uploaded'`; `POST /api/predictions/{id}/start` bernama `api.predictions.start`, menjawab `200` dengan `{success, data: {id, status, queue_position}}`.

- [ ] **Step 1: Tulis migrasinya**

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * A state for "the files are here" that is not yet "waiting for a worker".
 *
 * Upload and analysis used to be one button: PredictionIntake created the
 * record as `pending` and dispatched in the same breath. The preview a
 * researcher asked for has to sit between those two things — look at what you
 * are about to submit, then submit it — so there has to be a state where the
 * frames exist and nothing is queued.
 *
 * `uploaded` goes in front of `pending` rather than after it. Everything that
 * counts the queue asks for `pending` and keeps working untouched.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement(
            "ALTER TABLE analysis_records MODIFY COLUMN status "
            . "ENUM('uploaded','pending','processing','completed','failed') "
            . "NOT NULL DEFAULT 'pending'"
        );
    }

    public function down(): void
    {
        // Anything still sitting at `uploaded` was never analysed. It becomes
        // `pending` so the column can narrow again — which means a rollback
        // queues work nobody confirmed. There is no better answer: the state
        // stops existing.
        DB::table('analysis_records')
            ->where('status', 'uploaded')
            ->update(['status' => 'pending']);

        DB::statement(
            "ALTER TABLE analysis_records MODIFY COLUMN status "
            . "ENUM('pending','processing','completed','failed') "
            . "NOT NULL DEFAULT 'pending'"
        );
    }
};
```

- [ ] **Step 2: Jalankan migrasinya**

Run: `cd be && php artisan migrate`
Expected: DONE.

- [ ] **Step 3: Tulis test yang gagal**

Berkas baru `be/tests/Feature/PredictionStartTest.php`:

```php
<?php

namespace Tests\Feature;

use App\Jobs\ProcessDeepLearningImage;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Upload and analysis are two steps.
 *
 * A researcher asked to see the frames before committing a run to a GPU that
 * is not always up, so an upload now lands as `uploaded` and stays there until
 * someone presses START.
 */
class PredictionStartTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;
    private User $stranger;
    private Model $model;

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

        $this->model = Model::create([
            'name' => 'deepCT TC-D', 'version' => 'v1', 'kind' => 'inference',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online', 'is_active' => true,
        ]);
    }

    private function record(array $overrides = []): AnalysisRecord
    {
        return AnalysisRecord::create(array_merge([
            'user_id' => $this->owner->id,
            'job_id' => 'job-' . uniqid(),
            'model_id' => $this->model->id,
            'file_name' => 'frames.zip',
            'input_folder' => 'predictions/1/job/input',
            'output_folder' => 'predictions/1/job/output',
            'status' => 'uploaded',
            'input_files_count' => 2,
            'expires_at' => now()->addHours(24),
        ], $overrides));
    }

    private function token(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    public function test_starting_queues_the_job_and_moves_it_to_pending(): void
    {
        Bus::fake();
        $record = $this->record();

        $this->apiAs($this->token($this->owner))
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertOk()
            ->assertJsonPath('data.status', 'pending');

        $this->assertSame('pending', $record->fresh()->status);
        Bus::assertDispatched(ProcessDeepLearningImage::class);
    }

    /**
     * A double tap on a phone must not queue the work twice — the same job
     * running on two workers would write over its own output folder.
     */
    public function test_starting_twice_is_refused_and_queues_once(): void
    {
        Bus::fake();
        $record = $this->record();
        $token = $this->token($this->owner);

        $this->apiAs($token)
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertOk();

        $this->apiAs($token)
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertStatus(409);

        Bus::assertDispatchedTimes(ProcessDeepLearningImage::class, 1);
    }

    /**
     * 404 rather than 403: a stranger must not learn that the record exists.
     * Matches findOwned(), which every other prediction route uses.
     */
    public function test_someone_elses_upload_cannot_be_started(): void
    {
        Bus::fake();
        $record = $this->record();

        $this->apiAs($this->token($this->stranger))
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertNotFound();

        Bus::assertNothingDispatched();
    }

    public function test_an_expired_upload_cannot_be_started(): void
    {
        Bus::fake();
        $record = $this->record(['files_deleted_at' => now()->subMinute()]);

        $this->apiAs($this->token($this->owner))
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertStatus(410);

        Bus::assertNothingDispatched();
    }
}
```

- [ ] **Step 4: Jalankan test, pastikan gagal**

Run: `cd be && php artisan test --filter=PredictionStartTest`
Expected: FAIL, keempatnya 404 dari router — rutenya belum ada.

- [ ] **Step 5: `PredictionIntake` berhenti mengantrikan**

Di `be/app/Services/PredictionIntake.php`, ganti `'status' => 'pending',` di baris 72:

```php
            // Not `pending`: the files are here, but nobody has said to run
            // them yet. POST /predictions/{id}/start does that.
            'status' => 'uploaded',
```

dan **hapus** baris 77 beserta baris kosong di sekitarnya:

```php
        ProcessDeepLearningImage::dispatch($record);
```

Bila `use App\Jobs\ProcessDeepLearningImage;` di baris 5 jadi tidak terpakai, buang import-nya. Periksa dulu — berkas itu mungkin memakainya di tempat lain.

Deskripsi aktivitas di bawahnya berbunyi `"Started prediction with {$extracted} input frame(s)"`. Ganti jadi:

```php
            'description' => "Uploaded {$extracted} input frame(s)",
```

karena tidak ada prediksi yang dimulai di sini lagi, dan log aktivitas yang mengaku sebaliknya akan menyesatkan siapa pun yang membacanya nanti.

- [ ] **Step 6: Tulis `start()`**

Di `be/app/Http/Controllers/API/AnalysisController.php`, tambahkan setelah `frames()`:

```php
    /**
     * POST /api/predictions/{id}/start — queue an upload that is waiting.
     *
     * Upload and analysis are separate so a researcher can look at the frames
     * before spending a GPU slot on them. This is the second half.
     */
    public function start(Request $request, $id)
    {
        // 404 rather than 403 for someone else's record: whether it exists is
        // not their business either.
        $prediction = $this->findOwned($request, $id);

        if (!$prediction->hasFiles()) {
            return response()->json([
                'success' => false,
                'message' => 'Files have expired and been deleted',
            ], 410);
        }

        if ($prediction->status !== 'uploaded') {
            // A double tap on a phone reaches here. Two workers on one job
            // would write over the same output folder.
            return response()->json([
                'success' => false,
                'message' => 'This analysis has already been started.',
            ], 409);
        }

        $prediction->update(['status' => 'pending']);

        ProcessDeepLearningImage::dispatch($prediction);

        UserActivity::create([
            'user_id' => $request->user()->id,
            'model_id' => $prediction->model_id,
            'activity_type' => 'prediction',
            'description' => "Started analysis of {$prediction->input_files_count} frame(s)",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Analysis queued.',
            'data' => [
                'id' => $prediction->id,
                'status' => $prediction->status,
                'queue_position' => AnalysisRecord::where('status', 'pending')
                    ->where('created_at', '<', $prediction->created_at)
                    ->count() + 1,
            ],
        ]);
    }
```

Tambahkan `use App\Jobs\ProcessDeepLearningImage;` dan `use App\Models\UserActivity;` di bagian atas berkas bila belum ada — periksa dulu.

- [ ] **Step 7: Rute**

Di `be/routes/api.php`, di dalam grup `predictions`, setelah baris `frames`:

```php
        Route::post('/{id}/start', [AnalysisController::class, 'start'])->name('api.predictions.start');
```

Perhatikan urutannya: ia harus berada **setelah** deklarasi `/uploads`, atau `uploads` akan tertelan sebagai `{id}` — alasan yang sudah ditulis di komentar baris 214-215.

- [ ] **Step 8: Bersihkan cache rute**

Run: `cd be && php artisan route:clear && php artisan route:list | grep predictions.start`
Expected: rutenya muncul. Tanpa langkah ini ia tidak akan terlihat oleh test maupun server — `bootstrap/cache/routes-v7.php` membuat `routes/api.php` tidak dibaca sama sekali (CLAUDE.md).

- [ ] **Step 9: Jalankan test, pastikan lulus**

Run: `cd be && php artisan test --filter=PredictionStartTest`
Expected: PASS, 4 test.

- [ ] **Step 10: Seluruh test backend, dan perhatikan yang rusak**

Run: `cd be && php artisan test`

Expected: **beberapa gagal.** `PredictionPipelineTest` dan `ChunkedUploadTest` menegaskan bahwa unggah mengantrikan pekerjaan dan menghasilkan status `pending` — dan itu memang sengaja tidak lagi benar.

Perbaiki dengan menambahkan panggilan `start` di test-test itu, **bukan** dengan melemahkan asersinya. Sebuah test yang dulu membuktikan "unggah menghasilkan pekerjaan yang antre" sekarang harus membuktikan "unggah lalu start menghasilkan pekerjaan yang antre". Bila sebuah asersi jadi tidak punya makna, hapus test-nya dan katakan alasannya di pesan commit — jangan biarkan ia lulus tanpa menguji apa pun.

- [ ] **Step 11: Commit**

```bash
git add be/database/migrations/2026_08_23_090001_add_uploaded_status_to_analysis_records.php be/app/Services/PredictionIntake.php be/app/Http/Controllers/API/AnalysisController.php be/routes/api.php be/tests
git commit -m "Let an upload exist without queueing it"
```

---

### Task 2: Penelusur diangkat jadi widget bersama

**Files:**
- Create: `fe/lib/widgets/frame_stack_viewer.dart`
- Modify: `fe/lib/screens/user/frame_gallery_screen.dart` — hapus `_FrameViewer` (baris 297-421), pakai widget baru
- Test: `fe/test/frame_stack_viewer_test.dart` (baru)

**Interfaces:**
- Consumes: `PredictionFrame` (`name`, `kind`, `isGenerated`, `frameNumber`).
- Produces: `FrameStackViewer({required List<PredictionFrame> frames, required int initialIndex, required Future<Uint8List> Function(String name) loader})` — sebuah `Scaffold` penuh layar, dibuka lewat `Navigator.push`.

- [ ] **Step 1: Tulis test yang gagal**

Berkas baru `fe/test/frame_stack_viewer_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/prediction_frame.dart';
import 'package:fe/widgets/frame_stack_viewer.dart';

/// A 1x1 transparent PNG — enough for Image.memory to decode without
/// reaching for a real frame.
final _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
  0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0,
  1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

List<PredictionFrame> _frames() => const [
  PredictionFrame(name: 'frame_001.tif', kind: 'input', size: 100),
  PredictionFrame(name: 'frame_002.tif', kind: 'output', size: 100),
  PredictionFrame(name: 'frame_003.tif', kind: 'output', size: 100),
  PredictionFrame(name: 'frame_004.tif', kind: 'input', size: 100),
];

Widget _host(List<PredictionFrame> frames) => MaterialApp(
  home: FrameStackViewer(
    frames: frames,
    initialIndex: 0,
    loader: (_) async => _png,
  ),
);

void main() {
  testWidgets('a slider stands in for stepping through the stack', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_frames()));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('the badge names what the current frame is', (tester) async {
    await tester.pumpWidget(_host(_frames()));
    await tester.pumpAndSettle();

    // Frame one is an uploaded boundary.
    expect(find.text('INPUT'), findsOneWidget);
    expect(find.text('MODEL OUTPUT'), findsNothing);
  });

  testWidgets('moving the slider moves the frame', (tester) async {
    await tester.pumpWidget(_host(_frames()));
    await tester.pumpAndSettle();

    // Frame two is generated, so the badge has to change with it.
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1);
    await tester.pumpAndSettle();

    expect(find.text('MODEL OUTPUT'), findsOneWidget);
  });

  testWidgets('generated frames are marked on the slider track', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_frames()));
    await tester.pumpAndSettle();

    // Two of the four frames are output, so two ticks. Seeing where the
    // model's work landed is the whole reason the slider beats arrow keys.
    expect(find.byKey(const Key('frame-tick-1')), findsOneWidget);
    expect(find.byKey(const Key('frame-tick-2')), findsOneWidget);
    expect(find.byKey(const Key('frame-tick-0')), findsNothing);
  });

  testWidgets('a stack with no generated frames shows no ticks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const [
        PredictionFrame(name: 'frame_001.tif', kind: 'input', size: 100),
        PredictionFrame(name: 'frame_002.tif', kind: 'input', size: 100),
      ]),
    );
    await tester.pumpAndSettle();

    // This is the state right after upload, before anything has been
    // interpolated.
    expect(find.byKey(const Key('frame-tick-0')), findsNothing);
    expect(find.byKey(const Key('frame-tick-1')), findsNothing);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/frame_stack_viewer_test.dart`
Expected: FAIL saat kompilasi — `frame_stack_viewer.dart` belum ada.

- [ ] **Step 3: Pindahkan widget-nya**

Salin seluruh `_FrameViewer` dan `_FrameViewerState` dari
`fe/lib/screens/user/frame_gallery_screen.dart:297-421` ke berkas baru
`fe/lib/widgets/frame_stack_viewer.dart`, ganti namanya jadi `FrameStackViewer`
dan `_FrameStackViewerState`, dan buat konstruktornya publik (`const
FrameStackViewer({super.key, ...})`).

Import yang dibutuhkan berkas baru: `dart:typed_data`,
`package:flutter/material.dart`, `../models/prediction_frame.dart`,
`../theme/app_theme.dart`.

Beri dokumentasi kelas:

```dart
/// Scrub through a stack of frames the way ImageJ does.
///
/// Lives here rather than inside the gallery screen because three places need
/// it: the upload screen shows the frames just sent, the results screen shows
/// those merged with what the model produced, and training shows its own.
```

- [ ] **Step 4: Tambahkan slider, tick, dan badge**

Di `_FrameStackViewerState`, ganti `Padding` berisi keterangan di bawah gambar
(baris 401-418 pada berkas asal) dengan:

```dart
            _buildTrack(context),
```

dan tambahkan metode berikut ke state:

```dart
  /// The slider, with a mark above every frame the model produced.
  ///
  /// Two-way: dragging the slider turns the page, and swiping the page moves
  /// the slider. One-way would leave the slider lying as soon as someone
  /// swiped the image.
  Widget _buildTrack(BuildContext context) {
    final frame = widget.frames[_index];
    final last = widget.frames.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The ticks sit in their own row above the slider rather than being
          // painted into it: a Row of Expanded flexes lines each mark up with
          // its frame without a custom track painter.
          SizedBox(
            height: 6,
            child: Row(
              children: [
                for (var i = 0; i < widget.frames.length; i++)
                  Expanded(
                    child: widget.frames[i].isGenerated
                        ? Container(
                            key: Key('frame-tick-$i'),
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: AppTheme.warning,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          if (last > 0)
            Slider(
              value: _index.toDouble(),
              min: 0,
              max: last.toDouble(),
              divisions: last,
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              onChanged: (v) {
                final next = v.round();
                if (next == _index) return;
                setState(() => _index = next);
                _pages.jumpToPage(next);
              },
            ),
          Text(
            frame.isGenerated
                ? 'Interpolated by the model'
                : 'Uploaded boundary frame',
            style: TextStyle(
              color: frame.isGenerated ? AppTheme.warning : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
```

Dan letakkan badge di atas gambar. Bungkus `PageView.builder` yang ada dengan
`Stack`:

```dart
              child: Stack(
                children: [
                  PageView.builder(
                    // ... isi yang sudah ada, tidak berubah ...
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: frame.isGenerated
                          ? AppTheme.warning
                          : Colors.white24,
                      child: Text(
                        frame.isGenerated ? 'MODEL OUTPUT' : 'INPUT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: frame.isGenerated
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
```

Badge ada di gambar, bukan di bawahnya: mata sedang di gambar, dan keterangan
yang jauh dari sana tidak terbaca.

`jumpToPage` dan bukan `animateToPage`: menggeser slider adalah pencarian, dan
animasi 300 ms di setiap langkah membuatnya terasa lengket.

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/frame_stack_viewer_test.dart`
Expected: PASS, 5 test.

- [ ] **Step 6: Galeri memakai widget baru**

Di `fe/lib/screens/user/frame_gallery_screen.dart`, hapus seluruh
`_FrameViewer` dan `_FrameViewerState`, tambahkan
`import '../../widgets/frame_stack_viewer.dart';`, dan ganti pemanggilannya —
cari `_FrameViewer(` dan jadikan `FrameStackViewer(`.

- [ ] **Step 7: Analisa dan seluruh test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 158 test lulus.

- [ ] **Step 8: Commit**

```bash
git add fe/lib/widgets/frame_stack_viewer.dart fe/lib/screens/user/frame_gallery_screen.dart fe/test/frame_stack_viewer_test.dart
git commit -m "Lift the frame viewer out of the gallery and give it a slider"
```

---

### Task 3: Beberapa `.tif` dibungkus di klien

**Files:**
- Modify: `fe/pubspec.yaml` — tambah `archive`
- Create: `fe/lib/utils/frame_bundle.dart`
- Modify: `fe/lib/screens/user/upload_screen.dart` — `_pickFile`
- Test: `fe/test/frame_bundle_test.dart` (baru)

**Interfaces:**
- Produces: `Future<({Uint8List bytes, String filename})> bundleFrames(List<({String name, Uint8List bytes})> files)` di `frame_bundle.dart`; melempar `ArgumentError` bila daftarnya kosong.

- [ ] **Step 1: Tambahkan paketnya**

Run: `cd fe && flutter pub add archive`
Expected: `win32` tetap 5.15.0. Bila naik ke 6.x, hentikan.

- [ ] **Step 2: Tulis test yang gagal**

Berkas baru `fe/test/frame_bundle_test.dart`:

```dart
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/utils/frame_bundle.dart';

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  test('several frames become one archive keeping their names', () async {
    // The numbering in the filename is what tells the backend where the gaps
    // are. Renaming would destroy exactly the information it needs.
    final bundle = await bundleFrames([
      (name: 'frame_001.tif', bytes: _bytes('one')),
      (name: 'frame_007.tif', bytes: _bytes('seven')),
    ]);

    final archive = ZipDecoder().decodeBytes(bundle.bytes);
    final names = archive.files.map((f) => f.name).toList()..sort();

    expect(names, ['frame_001.tif', 'frame_007.tif']);
    expect(bundle.filename, endsWith('.zip'));
  });

  test('the bytes of each frame survive the round trip', () async {
    final bundle = await bundleFrames([
      (name: 'frame_001.tif', bytes: _bytes('the actual pixels')),
    ]);

    final archive = ZipDecoder().decodeBytes(bundle.bytes);
    final content = String.fromCharCodes(archive.files.single.content as List<int>);

    expect(content, 'the actual pixels');
  });

  test('a single frame is still bundled', () async {
    // The backend refuses one frame — interpolation needs two boundaries —
    // and it already has a message for that. Duplicating the rule here would
    // be two places that can disagree.
    final bundle = await bundleFrames([
      (name: 'frame_001.tif', bytes: _bytes('one')),
    ]);

    expect(ZipDecoder().decodeBytes(bundle.bytes).files, hasLength(1));
  });

  test('an empty list is a programming error, not a silent empty zip', () {
    expect(() => bundleFrames(const []), throwsArgumentError);
  });
}
```

- [ ] **Step 3: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/frame_bundle_test.dart`
Expected: FAIL — `frame_bundle.dart` belum ada.

- [ ] **Step 4: Tulis pembungkusnya**

Berkas baru `fe/lib/utils/frame_bundle.dart`:

```dart
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Wrap loose `.tif` frames into the ZIP the upload path already expects.
///
/// A researcher picking six frames out of a folder should not have to zip them
/// first, and the backend should not grow a second intake shape for the same
/// thing. So the archive is built here and travels the existing route.
///
/// **Names are kept exactly.** The numbering inside them is what tells the
/// backend where the gaps are; normalising it would destroy the one piece of
/// information the whole interpolation depends on.
Future<({Uint8List bytes, String filename})> bundleFrames(
  List<({String name, Uint8List bytes})> files,
) async {
  if (files.isEmpty) {
    throw ArgumentError('bundleFrames needs at least one file');
  }

  final archive = Archive();

  for (final file in files) {
    archive.addFile(ArchiveFile(file.name, file.bytes.length, file.bytes));
  }

  final encoded = ZipEncoder().encode(archive);

  return (
    bytes: Uint8List.fromList(encoded),
    filename: 'frames.zip',
  );
}
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/frame_bundle_test.dart`
Expected: PASS, 4 test.

- [ ] **Step 6: Pemilih berkas menerima banyak `.tif`**

Di `fe/lib/screens/user/upload_screen.dart`, ganti `_pickFile` sehingga
memanggil `FilePicker` dengan `allowMultiple: true`, lalu:

```dart
    final picked = result?.files.where((f) => f.bytes != null).toList() ?? [];
    if (picked.isEmpty) return;

    final zips = picked.where((f) => hasExtension(f.name, const ['zip']));
    final tiffs = picked.where((f) => hasExtension(f.name, const ['tif', 'tiff']));

    if (zips.length == 1 && tiffs.isEmpty && picked.length == 1) {
      setState(() {
        _fileBytes = picked.single.bytes;
        _fileName = picked.single.name;
      });
      return;
    }

    if (tiffs.length == picked.length) {
      // Bundled here so the backend keeps one intake shape. The names travel
      // unchanged; their numbering is what marks the gaps.
      final bundle = await bundleFrames([
        for (final f in tiffs) (name: f.name, bytes: f.bytes!),
      ]);

      setState(() {
        _fileBytes = bundle.bytes;
        _fileName = bundle.filename;
      });
      return;
    }

    setState(() => _uploadError =
        'Choose one .zip archive, or one or more .tif frames — not a mixture.');
```

Tambahkan `import '../../utils/frame_bundle.dart';`.

**Baca `_pickFile` yang ada lebih dulu** dan sesuaikan nama field state
(`_fileBytes`, `_fileName`, `_uploadError`) dengan yang benar-benar dipakai di
sana; nama di atas diambil dari pembacaan sebelumnya tetapi berkas itu sudah
disunting di bagian A.

Pertahankan `type: FileType.any` dan `withData: true` yang sudah ada, beserta
komentarnya. **Jangan pernah `FileType.custom`.**

- [ ] **Step 7: Analisa dan seluruh test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 162 test lulus.

- [ ] **Step 8: Commit**

```bash
git add fe/pubspec.yaml fe/pubspec.lock fe/lib/utils/frame_bundle.dart fe/lib/screens/user/upload_screen.dart fe/test/frame_bundle_test.dart
git commit -m "Let a researcher pick loose .tif frames instead of zipping them first"
```

---

### Task 4: Unggah, lihat, lalu analisis

**Files:**
- Modify: `fe/lib/models/prediction.dart` — getter `isUploaded`
- Modify: `fe/lib/services/prediction_service.dart` — metode `start`
- Modify: `fe/lib/screens/user/upload_screen.dart` — dua langkah
- Modify: `fe/lib/screens/user/prediction_history_screen.dart` — status baru

**Interfaces:**
- Consumes: `POST /predictions/{id}/start` dari Task 1; `FrameStackViewer` dari Task 2.
- Produces: `PredictionService.start(int id)` mengembalikan `Future<void>`; `Prediction.isUploaded`.

- [ ] **Step 1: Model dan layanan**

Di `fe/lib/models/prediction.dart`, di samping `isPending` dan kawan-kawan di baris 107-110:

```dart
  /// Files are on the server and nothing is queued yet — the state a
  /// prediction sits in while the researcher looks at what they just sent.
  bool get isUploaded => status == 'uploaded';
```

Di `fe/lib/services/prediction_service.dart`, di samping metode lain:

```dart
  /// POST /predictions/{id}/start — queue an upload that is waiting.
  Future<void> start(int id) async {
    await _api.post('${ApiConfig.predictions}/$id/start');
  }
```

Periksa nama konstanta `ApiConfig.predictions` di
`fe/lib/config/api_config.dart` dan sesuaikan.

- [ ] **Step 2: Layar unggah jadi dua langkah**

Tombolnya sekarang berbunyi `START ANALYSIS` dan melakukan keduanya sekaligus.
Pisahkan:

- Tombol pertama, `UPLOAD`, menjalankan unggah yang sudah ada. Saat selesai ia
  **tidak** memanggil `widget.onQueued` melainkan menyimpan `Prediction` yang
  kembali ke state, dan memuat daftar frame-nya lewat
  `PredictionService.frames(id)`.
- Di bawahnya muncul `FrameStackViewer` berisi frame yang baru naik, dengan
  kalimat: `These are the frames you just uploaded. Scrub through them, then
  start the analysis.`
- Tombol kedua, `START ANALYSIS`, memanggil `start(id)` lalu
  `widget.onQueued?.call(prediction)` seperti sebelumnya.

Sertakan jalan keluar: sebuah `DISCARD` yang memanggil
`PredictionService.destroy(id)` dan mengembalikan layar ke keadaan awal —
memilih berkas yang salah tidak boleh berarti terpaksa menjalankannya, dan
tanpa ini satu-satunya jalan keluar adalah meninggalkan unggahan
menggantung sampai kedaluwarsa.

- [ ] **Step 3: Riwayat mengenali status baru**

Di `fe/lib/screens/user/prediction_history_screen.dart`, tambahkan di samping
cabang `isCompleted` dan `isPending` yang ada di baris 315 dan 387-391:

```dart
              if (prediction.isUploaded)
                Text(
                  'Ready to analyse',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
```

`Ready to analyse`, bukan `Uploaded`: yang berguna bagi periset adalah apa yang
bisa ia lakukan berikutnya, bukan apa yang barusan terjadi.

Bila entri riwayat menampilkan lencana status, beri `uploaded` warnanya
sendiri — `AppTheme.accent`, berbeda dari kuning `pending` supaya "menunggu
Anda" tidak terbaca sebagai "menunggu worker".

- [ ] **Step 4: Analisa dan seluruh test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 162 test lulus.

- [ ] **Step 5: Commit**

```bash
git add fe/lib/models/prediction.dart fe/lib/services/prediction_service.dart fe/lib/screens/user/upload_screen.dart fe/lib/screens/user/prediction_history_screen.dart
git commit -m "Upload, look, then analyse"
```

---

### Task 5: Buktikan di perangkat, dan terhadap GPU sungguhan

Tidak ada kode di sini. Ini task yang membuat sisanya berarti.

**Files:** tidak ada.

- [ ] **Step 1: Bangun dan pasang**

```bash
cd fe && flutter build apk --release
cd be && npm run serve:all
```

`serve:all` dan bukan `octane` saja: tanpa queue worker unggahan akan berhenti
di `pending` selamanya, dan tanpa scheduler status model jadi basi. Keduanya
diperlukan untuk membuktikan alur ini.

Jalankan di `SM A325F`:

```bash
cd fe && flutter run --release -d RR8RC06T1LY
```

- [ ] **Step 2: Alur C, di perangkat**

1. Pilih **beberapa berkas `.tif`** sekaligus — bukan ZIP. Ia harus terbungkus
   dan terunggah.
2. Penelusur muncul. Geser slider dengan jari. Cubit untuk memperbesar.
3. Tekan `START ANALYSIS`.
4. Tunggu selesai, buka hasilnya, dan geser lagi — kali ini frame sisipan model
   harus bertanda, dengan tick di jalur slider.

- [ ] **Step 3: Semua yang tertunda sejak bagian A**

Di perangkat yang sama, satu putaran:

- tekan-lama sebuah teks di dasbor, lalu salin;
- tekan-lama teks di dalam dialog, misalnya kata sandi hasil reset admin;
- gulung kotak aktivitas di dasbor — ia harus berhenti sekitar empat baris;
- buka Model Management sebagai admin: kalimat ramah dengan kode mentah di
  bawahnya;
- isi kolom telepon, dan buat akun kedua dengan nomor yang sama persis;
- putar video berita dan geser ke tengah;
- buka panel emoji, sisipkan emoji di tengah kalimat;
- **matikan backend, lalu kirim pesan** — gelembungnya harus merah dan teks
  Anda harus kembali ke kolom ketik.

Yang terakhir itu yang paling mudah salah dan paling mahal kalau salah.

- [ ] **Step 4: Satu prediksi nyata terhadap worker**

C1 menyentuh `PredictionIntake` dan enum status, dan pipeline prediksi adalah
satu-satunya jalur di proyek ini yang pernah dibuktikan ujung-ke-ujung terhadap
GPU sungguhan (ROADMAP, "Sudah selesai" no. 2). Suite yang hijau tidak
membuktikan jalurnya masih utuh.

Butuh sesi Kaggle yang hidup dengan worker berjalan dan endpoint-nya terdaftar
di Model Management. Dua frame batas dengan celah, seperti run 18 Agustus.

**Bila worker tidak bisa dihidupkan, hentikan dan katakan begitu.** Jangan
centang C sebagai selesai; catat di ROADMAP bahwa jalurnya belum dibuktikan
ulang setelah dipecah dua. Itu keadaan yang sama persis yang membuat no. 10
bertahun-tahun ditandai "TERPASANG, BELUM DIJALANI".

- [ ] **Step 5: Catat apa yang benar-benar dilihat**

Setiap butir di Step 2 dan 3 yang **tidak** dikerjakan disebutkan namanya di
ROADMAP, bukan dibiarkan tersirat.

---

### Task 6: Catat dan centang

**Files:**
- Modify: `API.md` — endpoint `start`, status `uploaded`
- Modify: `ARCHITECTURE.md` — alur prediksi dua langkah
- Modify: `CHANGELOG.md`
- Modify: `ROADMAP.md` §12 item C

- [ ] **Step 1: Verifikasi penuh**

```bash
cd be && php artisan test
cd ../fe && flutter analyze
flutter test
flutter build apk --release
```

- [ ] **Step 2: `API.md`**

Tambahkan `POST /predictions/{id}/start` ke tabel dan uraiannya: 409 bila sudah
dimulai, 404 bila bukan milik pemanggil, 410 bila berkasnya kedaluwarsa.
Perbarui daftar nilai `status` dengan `uploaded`, dan katakan bahwa
`finalize` **tidak lagi** mengantrikan.

- [ ] **Step 3: `ARCHITECTURE.md`**

Perbarui uraian alur prediksi: unggah dan analisis adalah dua permintaan
terpisah, dengan alasannya — preview harus berada di antaranya.

- [ ] **Step 4: `CHANGELOG.md`**

Di puncak. Sebutkan **mengapa** alurnya dipecah, dan bahwa alternatifnya
(dekoder TIFF di Dart) ditolak karena akan menghasilkan dua dekoder yang bisa
berbeda. Sebutkan juga tiga hal yang ternyata sudah ada, sehingga C jauh lebih
kecil daripada bunyinya.

- [ ] **Step 5: `ROADMAP.md`**

Centang C **hanya bila Task 5 benar-benar dikerjakan**, dengan daftar apa yang
dilihat dan apa yang tidak. Bila run GPU tidak terjadi, jangan dicentang.

- [ ] **Step 6: Commit**

```bash
git add API.md ARCHITECTURE.md CHANGELOG.md ROADMAP.md
git commit -m "Record what part C changed and why"
```

---

## Catatan untuk pelaksana

**Task 1 akan memerahkan suite, dan itu benar.** `PredictionPipelineTest` dan
`ChunkedUploadTest` menegaskan bahwa unggah mengantrikan pekerjaan. Perbaikannya
adalah menambahkan panggilan `start` ke test-test itu, bukan melemahkan
asersinya.

**Task 5 bukan formalitas.** Ia satu-satunya bagian rencana ini yang
membuktikan apa pun tentang perangkat sungguhan dan GPU sungguhan. Rencana
sebelumnya di sesi ini menunda pemeriksaan mata karena tidak ada perangkat;
sekarang ada, dan menundanya lagi berarti menumpuk hutang yang sama dengan
alasan yang sudah tidak berlaku.

**Tiga tempat rencana ini menyuruh membaca dulu:** nama field state di
`_pickFile` (Task 3 Step 6), nama konstanta `ApiConfig.predictions` (Task 4
Step 1), dan apakah `PredictionIntake` masih memakai `ProcessDeepLearningImage`
di tempat lain (Task 1 Step 5).
