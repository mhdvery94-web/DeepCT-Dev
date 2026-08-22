# Bagian B2 — Video News dan Messages: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admin bisa melampirkan video (maks 50 MB) pada berita riset, pesan bisa disisipi emoji lewat tombol pemilih, dan pesan yang sedang dikirim terlihat sedang dikirim.

**Architecture:** Video menempuh mesin unggah berpotongan yang sudah ada sebagai tujuan ketiga (`purpose: news_video`), karena `post_max_size` PHP adalah 8M dan satu POST 50 MB mustahil. Penyajiannya meniru endpoint gambar apa adanya — `BinaryFileResponse` sudah menangani Range, jadi seek tidak butuh kode. Status *pending* murni di sisi klien: tidak ada kolom, hanya gelembung yang muncul sebelum jawaban server tiba.

**Tech Stack:** Laravel 12 + Octane/RoadRunner, Flutter, MySQL, `video_player`, `emoji_picker_flutter`.

## Global Constraints

- **`MAX_VIDEO_BYTES = 50 * 1024 * 1024`** dan **`VIDEO_MIMES = ['video/mp4', 'video/webm']`**. `video/quicktime` sengaja di luar daftar: `.mov` tidak diputar Chrome di Android tanpa transcoding, dan mesin ini tidak punya apa pun untuk melakukannya.
- **Tidak ada kode HTTP Range yang ditulis.** Sudah terbukti bekerja: `GET /api/news/1/image` menjawab `Accept-Ranges: bytes`, dan `Range: bytes=0-99` dijawab `206` dengan `Content-Range: bytes 0-99/594`.
- **Video dan gambar keduanya opsional dan berdiri sendiri.** Sebuah post boleh punya keduanya, salah satu, atau tidak sama sekali.
- **Video hilang bersama post-nya dan saat diganti.** Tidak ada kedaluwarsa otomatis.
- **Bahasa antarmuka Inggris**, termasuk pesan kegagalan. Balasan ke pengguna dalam percakapan tetap Indonesia.
- **Sudut kotak** (`BorderRadius.zero`), `withValues(alpha:)` bukan `withOpacity`.
- **Jangan tambah dokumen status.** Hasil ke `CHANGELOG.md`, centang di `ROADMAP.md` §12 hanya setelah diverifikasi.
- **`file_picker` tetap `^11.0.0`** dan **jangan pernah minta `FileType.custom`** — pakai `FileType.any` lalu periksa nama sendiri dengan `hasExtension` di `lib/utils/file_extension.dart`. Alasannya panjang dan ada di CLAUDE.md.
- **Octane tidak bisa restart sendiri di Windows** — `npm run octane:reset` setelah mengubah PHP. `route:list` bukan bukti.
- **Test backend butuh `db_aict_test`.** `$this->apiAs($token)`, dan `Storage::fake('local')` bila test menyentuh berkas.
- **Dasar sebelum B2:** backend 256 test, Flutter 147 test, `flutter analyze` bersih.

---

### Task 1: Kolom video, penyajian, dan penghapusan

**Files:**
- Create: `be/database/migrations/2026_08_22_110001_add_video_to_news_posts_table.php`
- Modify: `be/app/Models/NewsPost.php` — konstanta setelah baris 39, `hasVideo()` setelah `hasImage()` di baris 66-69
- Modify: `be/app/Http/Controllers/API/NewsController.php` — `serialise()` baris 24-46, `video()` baru setelah `image()`, `deleteVideo()` setelah `deleteImage()`, dan `destroy()`
- Modify: `be/routes/api.php:56`
- Test: `be/tests/Feature/NewsVideoTest.php` (baru)

**Interfaces:**
- Produces: kolom `news_posts.video_path`, `video_mime` (`string(60)`), `video_size_bytes` (`unsignedBigInteger`), semuanya nullable. `NewsPost::VIDEO_MIMES`, `NewsPost::MAX_VIDEO_BYTES`, `NewsPost::hasVideo(): bool`. Rute `GET /api/news/{id}/video` bernama `api.news.video`. Payload post mendapat `has_video`, `video_url`, `video_size_bytes`.

- [ ] **Step 1: Tulis migrasinya**

Berkas `be/database/migrations/2026_08_22_110001_add_video_to_news_posts_table.php`:

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A video beside the photo, so a post can carry a clip of the activity.
 *
 * Mirrors the image pair, plus a size. 4 MB does not need announcing; 50 MB
 * does — the number is shown next to the play button so someone on a slow
 * connection knows what they are about to start.
 *
 * Both are optional and independent: a post may have neither, either, or both.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('news_posts', function (Blueprint $table) {
            $table->string('video_path')->nullable()->after('image_mime');
            $table->string('video_mime', 60)->nullable()->after('video_path');
            $table->unsignedBigInteger('video_size_bytes')->nullable()->after('video_mime');
        });
    }

    public function down(): void
    {
        Schema::table('news_posts', function (Blueprint $table) {
            $table->dropColumn(['video_path', 'video_mime', 'video_size_bytes']);
        });
    }
};
```

- [ ] **Step 2: Jalankan migrasinya**

Run: `cd be && php artisan migrate`
Expected: `2026_08_22_110001_add_video_to_news_posts_table ... DONE`

- [ ] **Step 3: Tulis test yang gagal**

Berkas baru `be/tests/Feature/NewsVideoTest.php`:

```php
<?php

namespace Tests\Feature;

use App\Models\NewsPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * A video attached to a research post: how it is served, and when it goes.
 *
 * Uploading is a separate path — a video is too large for one request, so it
 * arrives through the chunked uploader. That is covered in
 * NewsVideoUploadTest.
 */
class NewsVideoTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');

        $this->admin = User::create([
            'name' => 'Admin',
            'email' => 'admin@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'is_active' => true,
        ]);
    }

    private function postWithVideo(array $overrides = []): NewsPost
    {
        $path = UploadedFile::fake()
            ->create('clip.mp4', 64, 'video/mp4')
            ->store('news');

        return NewsPost::create(array_merge([
            'title' => 'Field trip',
            'summary' => 'A day at the reactor',
            'is_published' => true,
            'published_at' => now(),
            'video_path' => $path,
            'video_mime' => 'video/mp4',
            'video_size_bytes' => 65536,
        ], $overrides));
    }

    public function test_a_published_post_serves_its_video_to_anyone(): void
    {
        $post = $this->postWithVideo();

        $this->get("/api/news/{$post->id}/video")
            ->assertOk()
            ->assertHeader('Content-Type', 'video/mp4');
    }

    /**
     * The same rule the photo follows: a draft must not be findable by
     * guessing ids.
     */
    public function test_an_unpublished_post_hides_its_video_from_the_public(): void
    {
        $post = $this->postWithVideo(['is_published' => false, 'published_at' => null]);

        $this->get("/api/news/{$post->id}/video")->assertNotFound();
    }

    public function test_a_post_without_a_video_answers_404(): void
    {
        $post = NewsPost::create([
            'title' => 'Text only',
            'summary' => 'No media at all',
            'is_published' => true,
            'published_at' => now(),
        ]);

        $this->get("/api/news/{$post->id}/video")->assertNotFound();
    }

    public function test_the_listing_says_whether_a_post_has_a_video(): void
    {
        $withVideo = $this->postWithVideo();

        $response = $this->getJson('/api/news')->assertOk();

        $row = collect($response->json('data'))
            ->firstWhere('id', $withVideo->id);

        $this->assertTrue($row['has_video']);
        $this->assertSame("/news/{$withVideo->id}/video", $row['video_url']);
        $this->assertSame(65536, $row['video_size_bytes']);
    }

    public function test_a_post_without_a_video_says_so(): void
    {
        $post = NewsPost::create([
            'title' => 'Text only',
            'summary' => 'No media at all',
            'is_published' => true,
            'published_at' => now(),
        ]);

        $row = collect($this->getJson('/api/news')->json('data'))
            ->firstWhere('id', $post->id);

        $this->assertFalse($row['has_video']);
        $this->assertNull($row['video_url']);
    }

    /**
     * A 50 MB file left behind by a deleted post is the kind of thing that
     * fills a VPS disk without anyone deciding to.
     */
    public function test_deleting_a_post_deletes_its_video(): void
    {
        $post = $this->postWithVideo();
        $path = $post->video_path;

        $this->assertTrue(Storage::exists($path));

        $token = $this->tokenFor($this->admin->email, 'password123');
        $this->apiAs($token)->deleteJson("/api/admin/news/{$post->id}")->assertOk();

        $this->assertFalse(Storage::exists($path));
    }
}
```

- [ ] **Step 4: Jalankan test, pastikan gagal**

Run: `cd be && php artisan test --filter=NewsVideoTest`
Expected: FAIL. Rute `/api/news/{id}/video` belum ada, jadi test penyajian gagal 404 dari router; test daftar gagal dengan kunci `has_video` tidak ditemukan.

- [ ] **Step 5: Konstanta dan `hasVideo()` di model**

Di `be/app/Models/NewsPost.php`, setelah `MAX_IMAGE_BYTES` di baris 39:

```php
    /**
     * Video types accepted on upload.
     *
     * Two, and `video/quicktime` deliberately not among them: Chrome on
     * Android will not play a `.mov` without transcoding, and nothing on this
     * machine can transcode. Same reason the image list is narrow.
     */
    public const VIDEO_MIMES = ['video/mp4', 'video/webm'];

    /** 50 MB. Roughly three to four minutes — long enough for an activity
     * clip, short enough that fifty viewers is 2.5 GB of VPS bandwidth
     * rather than five. */
    public const MAX_VIDEO_BYTES = 50 * 1024 * 1024;
```

Dan setelah `hasImage()` di baris 66-69:

```php
    public function hasVideo(): bool
    {
        return $this->video_path !== null;
    }
```

Tambahkan `'video_path'`, `'video_mime'`, `'video_size_bytes'` ke `$fillable` bila berkas itu punya daftar `$fillable`; bila tidak, lewati langkah ini — periksa dulu, jangan menambahkan array `$fillable` yang belum ada.

- [ ] **Step 6: Payload menyebutkan video**

Di `be/app/Http/Controllers/API/NewsController.php`, dalam `serialise()`, setelah baris `'image_url' => ...`:

```php
            'has_video' => $post->hasVideo(),
            'video_url' => $post->hasVideo() ? "/news/{$post->id}/video" : null,
            // Shown beside the play button. 50 MB on a slow connection is
            // worth knowing about before you start it, which is why this has
            // no counterpart on the image.
            'video_size_bytes' => $post->video_size_bytes,
```

- [ ] **Step 7: Endpoint video**

Di `be/app/Http/Controllers/API/NewsController.php`, tepat setelah metode `image()`:

```php
    /**
     * GET /api/news/{id}/video — the clip itself.
     *
     * Same visibility rule as the photo: public for a published post, admin
     * only for a draft, so a draft cannot be found by guessing ids.
     *
     * `response()->file()` returns a Symfony BinaryFileResponse, which
     * answers Range requests on its own — verified: a `Range: bytes=0-99`
     * against the image endpoint returns 206 with a correct Content-Range.
     * That is what lets a player seek, and it is why there is no range
     * handling written here.
     */
    public function video(Request $request, $id)
    {
        $post = NewsPost::findOrFail($id);

        if (!$post->is_published) {
            $user = $request->user() ?? auth('sanctum')->user();

            if (!$user || $user->role !== 'admin') {
                abort(404);
            }
        }

        if (!$post->hasVideo() || !Storage::exists($post->video_path)) {
            abort(404);
        }

        return response()->file(Storage::path($post->video_path), [
            'Content-Type' => $post->video_mime ?? 'application/octet-stream',
            // Same reasoning as the photo: replacing a video writes a new
            // filename, so a changed video is never the same URL.
            'Cache-Control' => 'public, max-age=3600',
        ]);
    }
```

- [ ] **Step 8: Penghapusan**

Di `be/app/Http/Controllers/API/NewsController.php`, tepat setelah `deleteImage()`:

```php
    private function deleteVideo(NewsPost $post): void
    {
        if ($post->video_path && Storage::exists($post->video_path)) {
            Storage::delete($post->video_path);
        }
    }
```

Lalu di `destroy()`, di sebelah pemanggilan `deleteImage($post)` yang sudah ada, tambahkan:

```php
        $this->deleteVideo($post);
```

Bila `destroy()` tidak memanggil `deleteImage()` sama sekali, cari di mana gambar dihapus saat post dihapus dan tambahkan di sana; bila memang tidak ada, tambahkan keduanya di `destroy()` sebelum `$post->delete()`.

- [ ] **Step 9: Rute**

Di `be/routes/api.php`, tepat setelah baris 56:

```php
Route::get('/news/{id}/video', [NewsController::class, 'video'])->name('api.news.video');
```

- [ ] **Step 10: Jalankan test, pastikan lulus**

Run: `cd be && php artisan test --filter=NewsVideoTest`
Expected: PASS, 6 test.

- [ ] **Step 11: Seluruh test backend**

Run: `cd be && php artisan test`
Expected: PASS, 262 test.

- [ ] **Step 12: Commit**

```bash
git add be/database/migrations/2026_08_22_110001_add_video_to_news_posts_table.php be/app/Models/NewsPost.php be/app/Http/Controllers/API/NewsController.php be/routes/api.php be/tests/Feature/NewsVideoTest.php
git commit -m "Give a research post somewhere to keep a video"
```

---

### Task 2: Unggah video lewat mesin yang sudah ada

**Files:**
- Modify: `be/app/Http/Controllers/API/PredictionUploadController.php` — `start()` baris 56-127, `finalize()` baris 213-268, dan metode `finalizeNewsVideo()` baru
- Test: `be/tests/Feature/NewsVideoUploadTest.php` (baru)

**Interfaces:**
- Consumes: `NewsPost::VIDEO_MIMES`, `NewsPost::MAX_VIDEO_BYTES`, `NewsPost::hasVideo()` dari Task 1.
- Produces: `POST /api/predictions/uploads` menerima `purpose: news_video` dengan `news_post_id`; `POST /api/predictions/uploads/{id}/finalize` menempelkan video ke post dan mengembalikan `{success, data: {video_url, video_size_bytes}}`.

- [ ] **Step 1: Tulis test yang gagal**

Berkas baru `be/tests/Feature/NewsVideoUploadTest.php`:

```php
<?php

namespace Tests\Feature;

use App\Models\NewsPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Attaching a video to a post.
 *
 * It goes through the chunked uploader rather than a plain POST because
 * post_max_size is 8M — verified: a 25 MB multipart POST is refused with
 * HTTP 413 by Laravel's ValidatePostSize. The uploader already serves two
 * purposes; this is the third, and the role check lives inside the branch
 * because the route itself is open to any signed-in user.
 */
class NewsVideoUploadTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $researcher;
    private NewsPost $post;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');

        $this->admin = User::create([
            'name' => 'Admin', 'email' => 'admin@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'admin', 'is_active' => true,
        ]);

        $this->researcher = User::create([
            'name' => 'Researcher', 'email' => 'researcher@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);

        $this->post = NewsPost::create([
            'title' => 'Field trip',
            'summary' => 'A day at the reactor',
            'is_published' => true,
            'published_at' => now(),
        ]);
    }

    private function token(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    private function start(User $as, array $overrides = [])
    {
        return $this->apiAs($this->token($as))->postJson('/api/predictions/uploads', array_merge([
            'purpose' => 'news_video',
            'news_post_id' => $this->post->id,
            'total_size' => 1024,
            'filename' => 'clip.mp4',
        ], $overrides));
    }

    /** The route is open to any signed-in user; this purpose is not. */
    public function test_a_researcher_cannot_start_a_news_video_upload(): void
    {
        $this->start($this->researcher)->assertForbidden();
    }

    public function test_an_administrator_can_start_one(): void
    {
        $this->start($this->admin)
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['upload_id', 'chunk_size']]);
    }

    /** Refused before a single byte travels, not after fifty megabytes do. */
    public function test_a_video_over_the_size_limit_is_refused_up_front(): void
    {
        $this->start($this->admin, [
            'total_size' => NewsPost::MAX_VIDEO_BYTES + 1,
        ])->assertStatus(422);
    }

    public function test_the_post_must_exist(): void
    {
        $this->start($this->admin, ['news_post_id' => 99999])->assertStatus(422);
    }

    public function test_a_video_arrives_and_attaches_to_the_post(): void
    {
        $bytes = $this->fakeMp4();

        $start = $this->start($this->admin, ['total_size' => strlen($bytes)])
            ->assertCreated();
        $uploadId = $start->json('data.upload_id');

        $this->apiAs($this->token($this->admin))
            ->call('PATCH', "/api/predictions/uploads/{$uploadId}", [], [], [], [
                'CONTENT_TYPE' => 'application/octet-stream',
            ], $bytes)
            ->assertOk();

        $this->apiAs($this->token($this->admin))
            ->postJson("/api/predictions/uploads/{$uploadId}/finalize")
            ->assertOk()
            ->assertJsonPath('data.video_size_bytes', strlen($bytes));

        $this->post->refresh();
        $this->assertTrue($this->post->hasVideo());
        $this->assertSame('video/mp4', $this->post->video_mime);
        $this->assertTrue(Storage::exists($this->post->video_path));
    }

    /**
     * The type is read from the assembled bytes, not from the filename and
     * not from what the client claimed — the same reason validatePayload()
     * uses `mimetypes:` rather than `mimes:` for the photo.
     */
    public function test_a_file_that_is_not_a_video_is_refused_at_finalize(): void
    {
        $bytes = str_repeat('not a video at all', 32);

        $uploadId = $this->start($this->admin, ['total_size' => strlen($bytes)])
            ->assertCreated()
            ->json('data.upload_id');

        $this->apiAs($this->token($this->admin))
            ->call('PATCH', "/api/predictions/uploads/{$uploadId}", [], [], [], [
                'CONTENT_TYPE' => 'application/octet-stream',
            ], $bytes)
            ->assertOk();

        $this->apiAs($this->token($this->admin))
            ->postJson("/api/predictions/uploads/{$uploadId}/finalize")
            ->assertStatus(422);

        $this->post->refresh();
        $this->assertFalse($this->post->hasVideo());
    }

    /** A replaced video must not leave the old one on disk. */
    public function test_replacing_a_video_deletes_the_previous_file(): void
    {
        $bytes = $this->fakeMp4();

        $first = $this->uploadVideo($bytes);
        $this->post->refresh();
        $oldPath = $this->post->video_path;

        $this->uploadVideo($bytes);
        $this->post->refresh();

        $this->assertNotSame($oldPath, $this->post->video_path);
        $this->assertFalse(Storage::exists($oldPath));
        $this->assertTrue(Storage::exists($this->post->video_path));

        unset($first);
    }

    private function uploadVideo(string $bytes): void
    {
        $uploadId = $this->start($this->admin, ['total_size' => strlen($bytes)])
            ->assertCreated()
            ->json('data.upload_id');

        $this->apiAs($this->token($this->admin))
            ->call('PATCH', "/api/predictions/uploads/{$uploadId}", [], [], [], [
                'CONTENT_TYPE' => 'application/octet-stream',
            ], $bytes)
            ->assertOk();

        $this->apiAs($this->token($this->admin))
            ->postJson("/api/predictions/uploads/{$uploadId}/finalize")
            ->assertOk();
    }

    /**
     * Enough of a real MP4 header that `mime_content_type` says video/mp4.
     * An `ftyp` box with the `isom` brand is what the detector looks for.
     */
    private function fakeMp4(): string
    {
        return "\x00\x00\x00\x20ftypisom\x00\x00\x02\x00isomiso2avc1mp41"
            . str_repeat("\x00", 512);
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd be && php artisan test --filter=NewsVideoUploadTest`
Expected: FAIL. `purpose: news_video` tidak lolos aturan `in:prediction,training`, jadi semuanya berhenti di 422.

**Bila `test_a_video_arrives_and_attaches_to_the_post` nanti gagal karena `mime_content_type` menolak `fakeMp4()`**, jangan longgarkan pemeriksaan mime-nya — perbaiki byte-nya. Jalankan `php -r "echo mime_content_type('berkas-uji.mp4');"` pada berkas MP4 sungguhan yang kecil dan sesuaikan header di pembantu itu. Melonggarkan pemeriksaan agar test lulus akan membuang justru perlindungan yang sedang diuji.

- [ ] **Step 3: `start()` menerima tujuan ketiga**

Di `be/app/Http/Controllers/API/PredictionUploadController.php`, dalam `start()`, ganti aturan `purpose` dan tambahkan dua aturan:

```php
            // Three purposes now. All three are a large file arriving in
            // pieces over an unreliable link, which is the entire problem this
            // controller solves — a second copy of it would drift from this
            // one the first time either was touched.
            'purpose' => 'nullable|in:prediction,training,news_video',
```

dan, di samping aturan training yang sudah ada:

```php
            // News video only.
            'news_post_id' => 'required_if:purpose,news_video|nullable|exists:news_posts,id',
```

Ganti aturan `total_size` supaya batasnya bergantung tujuan:

```php
            'total_size' => [
                'required',
                'integer',
                'min:1',
                'max:' . ($request->input('purpose') === 'news_video'
                    ? NewsPost::MAX_VIDEO_BYTES
                    : self::MAX_TOTAL_BYTES),
            ],
```

Tambahkan `use App\Models\NewsPost;` di bagian atas berkas.

- [ ] **Step 4: Pemeriksaan peran, dan simpan `news_post_id`**

Masih di `start()`, tepat setelah `$purpose = $validated['purpose'] ?? 'prediction';`:

```php
        // The route is open to every signed-in user, because uploading a
        // prediction is a researcher's job. Attaching a video to a research
        // post is not, so the role check lives here rather than on the route.
        if ($purpose === 'news_video' && $request->user()->role !== 'admin') {
            return $this->error('Only an administrator may attach a video to a post.', 403);
        }
```

Dan dalam array `writeMeta([...])`, di samping `'base_model_id'`:

```php
            'news_post_id' => $validated['news_post_id'] ?? null,
```

- [ ] **Step 5: `finalize()` bercabang ketiga**

Di `finalize()`, tepat setelah cabang training di baris 229-231:

```php
        if (($meta['purpose'] ?? 'prediction') === 'news_video') {
            return $this->finalizeNewsVideo($request, $uploadId, $meta, $partPath);
        }
```

- [ ] **Step 6: Tulis `finalizeNewsVideo()`**

Tepat setelah `finalizeTraining()`:

```php
    /**
     * Attach a finished upload to a news post.
     *
     * The type is read from the assembled bytes rather than the filename or
     * anything the client claimed, for the same reason `validatePayload()`
     * uses `mimetypes:` instead of `mimes:` for the photo: an extension is a
     * suggestion, and this machine cannot re-encode anything that turns out
     * to be something else.
     */
    private function finalizeNewsVideo(Request $request, string $uploadId, array $meta, string $partPath)
    {
        $userId = $request->user()->id;

        // Checked again here, not only at start(): the two calls are separate
        // requests and a role can change between them.
        if ($request->user()->role !== 'admin') {
            $this->discard($userId, $uploadId);
            return $this->error('Only an administrator may attach a video to a post.', 403);
        }

        $post = NewsPost::find($meta['news_post_id'] ?? null);

        if (!$post) {
            $this->discard($userId, $uploadId);
            return $this->error('That post no longer exists.', 404);
        }

        $absolute = Storage::path($partPath);
        $mime = mime_content_type($absolute) ?: 'application/octet-stream';

        if (!in_array($mime, NewsPost::VIDEO_MIMES, true)) {
            $this->discard($userId, $uploadId);
            return $this->error(
                'That file is not a video the platform can play. Use MP4 or WebM.',
                422
            );
        }

        // Replace rather than accumulate. A 50 MB file left behind is how a
        // VPS disk fills without anyone deciding to.
        if ($post->video_path && Storage::exists($post->video_path)) {
            Storage::delete($post->video_path);
        }

        $extension = $mime === 'video/webm' ? 'webm' : 'mp4';
        $finalPath = 'news/' . Str::uuid() . '.' . $extension;

        Storage::move($partPath, $finalPath);

        $post->update([
            'video_path' => $finalPath,
            'video_mime' => $mime,
            'video_size_bytes' => $meta['total_size'],
        ]);

        // The part file has become the final file, so only the metadata is
        // left to clean up.
        $this->discard($userId, $uploadId);

        return response()->json([
            'success' => true,
            'message' => 'Video attached.',
            'data' => [
                'video_url' => "/news/{$post->id}/video",
                'video_size_bytes' => $post->video_size_bytes,
            ],
        ]);
    }
```

`Str` sudah diimpor di berkas ini (dipakai `Str::uuid()` di `start()`); pastikan `Storage` juga — bila belum, tambahkan `use Illuminate\Support\Facades\Storage;`.

**Catatan tentang `discard()` setelah `Storage::move()`:** `move` memindahkan berkas potongan, jadi berkas itu sudah tidak ada di tempat lamanya. `discard()` harus menangani berkas yang hilang tanpa melempar — periksa isinya, dan bila ia memanggil `Storage::delete()` tanpa pengecekan, itu tetap aman (Laravel mengembalikan `false`, tidak melempar).

- [ ] **Step 7: Jalankan test, pastikan lulus**

Run: `cd be && php artisan test --filter=NewsVideoUploadTest`
Expected: PASS, 7 test.

- [ ] **Step 8: Seluruh test backend**

Run: `cd be && php artisan test`
Expected: PASS, 269 test.

- [ ] **Step 9: Muat ulang server dan buktikan langsung**

Run: `cd be && npm run octane:reset` lalu `npm run octane`

Dengan token admin dan sebuah berkas MP4 sungguhan berukuran ~10 MB, jalankan alur tiga langkah (`uploads` → `PATCH` potongan → `finalize`), lalu:

```bash
curl -s -o /dev/null -D - -H "Range: bytes=0-99" "http://127.0.0.1:8000/api/news/<id>/video" | grep -iE "^HTTP|content-range"
```

Expected: `HTTP/1.1 206 Partial Content` dan `Content-Range: bytes 0-99/<ukuran>`. Ini yang membuktikan seek akan bekerja pada video sungguhan, bukan hanya pada gambar 594 byte.

- [ ] **Step 10: Commit**

```bash
git add be/app/Http/Controllers/API/PredictionUploadController.php be/tests/Feature/NewsVideoUploadTest.php
git commit -m "Let a video reach the server in pieces, since 50MB cannot arrive in one"
```

---

### Task 3: Klien memutar video

**Files:**
- Modify: `fe/pubspec.yaml` — tambah `video_player`
- Modify: `fe/lib/models/news_post.dart`
- Create: `fe/lib/widgets/news_video_player.dart`
- Modify: `fe/lib/widgets/news_carousel.dart`
- Test: `fe/test/news_video_test.dart` (baru)

**Interfaces:**
- Consumes: `has_video`, `video_url`, `video_size_bytes` dari Task 1.
- Produces: `NewsPost.hasVideo`, `NewsPost.videoUrl`, `NewsPost.videoSizeBytes`, `NewsPost.videoSizeLabel`; widget `NewsVideoPlayer({required String url, required int? sizeBytes})`; `bool get videoPlaybackSupported`.

- [ ] **Step 1: Tambahkan paketnya**

Run: `cd fe && flutter pub add video_player`

Expected: 7 paket bertambah, dan **`win32` tetap 5.15.0**. Bila `win32` naik ke 6.x, hentikan — itu memutus `flutter_secure_storage` 9.x, dan alasannya ada di komentar `pubspec.yaml`.

- [ ] **Step 2: Tulis test yang gagal**

Berkas baru `fe/test/news_video_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/news_post.dart';

void main() {
  NewsPost parse(Map<String, dynamic> json) => NewsPost.fromJson(json);

  test('a post reports the video it has', () {
    final post = parse({
      'id': 7,
      'title': 'Field trip',
      'summary': 'A day at the reactor',
      'has_video': true,
      'video_url': '/news/7/video',
      'video_size_bytes': 12582912,
    });

    expect(post.hasVideo, isTrue);
    expect(post.videoUrl, '/news/7/video');
    expect(post.videoSizeBytes, 12582912);
  });

  test('a post with no video says so rather than throwing', () {
    // Older payloads and text-only posts both arrive without these keys.
    final post = parse({
      'id': 8,
      'title': 'Text only',
      'summary': 'No media',
    });

    expect(post.hasVideo, isFalse);
    expect(post.videoUrl, isNull);
    expect(post.videoSizeBytes, isNull);
  });

  test('the size is shown in units a person reads', () {
    // 50 MB on a slow connection is worth knowing about before you start it.
    expect(
      parse({'id': 1, 'title': 't', 'summary': 's', 'video_size_bytes': 12582912})
          .videoSizeLabel,
      '12.0 MB',
    );
    expect(
      parse({'id': 1, 'title': 't', 'summary': 's', 'video_size_bytes': 524288})
          .videoSizeLabel,
      '512 KB',
    );
    expect(
      parse({'id': 1, 'title': 't', 'summary': 's'}).videoSizeLabel,
      isNull,
    );
  });
}
```

- [ ] **Step 3: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/news_video_test.dart`
Expected: FAIL — `hasVideo` belum ada di `NewsPost`.

- [ ] **Step 4: Tambahkan field ke `NewsPost`**

Di `fe/lib/models/news_post.dart`, tambahkan di samping field gambar yang sudah ada:

```dart
  /// Whether a clip is attached. Independent of the photo: a post may have
  /// neither, either, or both.
  final bool hasVideo;

  /// Relative to the API root, like [imageUrl]. Null when there is no video.
  final String? videoUrl;

  /// Shown beside the play button — 50 MB on a slow connection is worth
  /// knowing about before you start it.
  final int? videoSizeBytes;
```

Tambahkan ketiganya ke konstruktor sebagai `this.hasVideo = false,`, `this.videoUrl,`, `this.videoSizeBytes,`, dan di `fromJson`:

```dart
      hasVideo: json['has_video'] == true,
      videoUrl: json['video_url']?.toString(),
      videoSizeBytes: json['video_size_bytes'] is num
          ? (json['video_size_bytes'] as num).toInt()
          : int.tryParse('${json['video_size_bytes'] ?? ''}'),
```

Dan sebuah getter di akhir kelas:

```dart
  /// Null when there is no video, so a caller can drop the label entirely
  /// rather than print "0 B".
  String? get videoSizeLabel {
    final bytes = videoSizeBytes;
    if (bytes == null) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/news_video_test.dart`
Expected: PASS, 3 test.

- [ ] **Step 6: Widget pemutar dengan jalan mundur**

Berkas baru `fe/lib/widgets/news_video_player.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/file_download.dart';

/// True where `video_player` actually has an implementation.
///
/// Android, iOS/macOS and web. There is no Windows or Linux plugin, and the
/// project carries `windows/` and `linux/` folders only because `flutter
/// create` made them — the product ships to web and Android.
///
/// Checked up front rather than caught: an exception thrown after the screen
/// is built is too late to change what was drawn.
bool get videoPlaybackSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Plays a post's clip, or offers it for download where it cannot be played.
class NewsVideoPlayer extends StatefulWidget {
  /// Relative to the API root, as the payload gives it.
  final String url;

  /// Shown beside the controls; null hides the label.
  final String? sizeLabel;

  const NewsVideoPlayer({super.key, required this.url, this.sizeLabel});

  @override
  State<NewsVideoPlayer> createState() => _NewsVideoPlayerState();
}

class _NewsVideoPlayerState extends State<NewsVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  String get _absolute => '${ApiConfig.baseUrl}${widget.url}';

  @override
  void initState() {
    super.initState();
    if (videoPlaybackSupported) _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(_absolute));

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!videoPlaybackSupported || _failed) return _fallback(context);

    final controller = _controller;
    if (controller == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        VideoProgressIndicator(controller, allowScrubbing: true),
        Row(
          children: [
            IconButton(
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () => setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              }),
            ),
            if (widget.sizeLabel != null)
              Text(
                widget.sizeLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }

  /// Shown where playback is unavailable — on desktop, or when the file will
  /// not open. Saying nothing at all would read as a broken page.
  Widget _fallback(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.movie_outlined, size: 20, color: AppTheme.textMuted),
            const SizedBox(width: 8),
            Text(
              _failed
                  ? 'This video could not be played here.'
                  : 'Video playback is not available on this platform.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => downloadFile(_absolute, 'video'),
          icon: const Icon(Icons.download, size: 18),
          label: Text(
            widget.sizeLabel == null
                ? 'DOWNLOAD VIDEO'
                : 'DOWNLOAD VIDEO (${widget.sizeLabel})',
          ),
        ),
      ],
    ),
  );
}
```

**Sebelum menulis ini, periksa tanda tangan `downloadFile` di
`fe/lib/utils/file_download.dart`** dan sesuaikan pemanggilannya. Berkas itu
adalah export bersyarat — **jangan pernah `import 'dart:html'`**, itu memutus
build Android di kompilasi kernel meski jalurnya tidak pernah dijalankan.

- [ ] **Step 7: Pasang di kartu berita**

Di `fe/lib/widgets/news_carousel.dart`, di tempat gambar slide digambar, tambahkan di bawahnya:

```dart
                if (post.hasVideo && post.videoUrl != null) ...[
                  const SizedBox(height: 12),
                  NewsVideoPlayer(
                    url: post.videoUrl!,
                    sizeLabel: post.videoSizeLabel,
                  ),
                ],
```

Tambahkan `import 'news_video_player.dart';`. Baca dulu struktur slide-nya dan tempatkan blok ini di kolom yang sama dengan gambar dan ringkasannya, bukan di dalam `Stack` yang menumpuk teks di atas foto.

- [ ] **Step 8: Analisa dan test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 150 test lulus.

- [ ] **Step 9: Bangun APK**

Run: `cd fe && flutter build apk --release`
Expected: berhasil. Ini paket baru pertama di B2, dan CLAUDE.md mencatat paket baru pernah mematahkan kompilasi Java di sini — jadi ini bukan formalitas.

- [ ] **Step 10: Commit**

```bash
git add fe/pubspec.yaml fe/pubspec.lock fe/lib/models/news_post.dart fe/lib/widgets/news_video_player.dart fe/lib/widgets/news_carousel.dart fe/test/news_video_test.dart
git commit -m "Play a post's video, and offer it for download where playing is impossible"
```

---

### Task 4: Admin mengunggah video

**Files:**
- Modify: `fe/lib/services/news_service.dart` — metode unggah video baru
- Modify: `fe/lib/screens/admin/news_management_screen.dart` — pemilih berkas dan kemajuan

**Interfaces:**
- Consumes: `POST /api/predictions/uploads` dengan `purpose: news_video` dari Task 2.
- Produces: `NewsService.uploadVideo({required int postId, required Uint8List bytes, required String filename, void Function(int sent, int total)? onProgress})` mengembalikan `Future<String>` berisi `video_url`.

- [ ] **Step 1: Baca loop chunk yang sudah ada**

Run: `cd fe && sed -n '1,120p' lib/services/researcher_training_service.dart`

Loop tiga langkah (`uploads` → `PATCH` per potongan → `finalize`) sudah ditulis dua kali, di `prediction_service.dart` dan di sini. **Salin bentuknya, jangan menemukan yang ketiga.** ROADMAP §10 sudah mencatat kedua salinan itu layak disatukan; menambah salinan ketiga tanpa menyatukannya adalah hutang yang bertambah, dan itu disebut di sini supaya keputusannya sadar.

- [ ] **Step 2: Tulis metode unggah**

Di `fe/lib/services/news_service.dart`, mengikuti bentuk yang Anda baca di Step 1:

```dart
  /// Attach a video to a post.
  ///
  /// Goes through the chunked uploader rather than a plain POST because
  /// post_max_size is 8 MB — a 50 MB video refused in one request with a 413
  /// is what sent this down the same path as prediction archives.
  ///
  /// Returns the relative `video_url` the payload will carry afterwards.
  Future<String> uploadVideo({
    required int postId,
    required Uint8List bytes,
    required String filename,
    void Function(int sent, int total)? onProgress,
  }) async {
    final start = await _api.post(
      ApiConfig.predictionUploads,
      data: {
        'purpose': 'news_video',
        'news_post_id': postId,
        'total_size': bytes.length,
        'filename': filename,
      },
    );

    final uploadId = start['data']['upload_id'].toString();
    final chunkSize = (start['data']['chunk_size'] as num).toInt();

    var sent = 0;
    while (sent < bytes.length) {
      final end = (sent + chunkSize).clamp(0, bytes.length);
      await _api.patchBytes(
        '${ApiConfig.predictionUploads}/$uploadId',
        bytes.sublist(sent, end),
      );
      sent = end;
      onProgress?.call(sent, bytes.length);
    }

    final done = await _api.post(
      '${ApiConfig.predictionUploads}/$uploadId/finalize',
    );

    return done['data']['video_url'].toString();
  }
```

**Sesuaikan nama metode `_api` dengan yang benar-benar ada di
`fe/lib/services/api_client.dart`** — `patchBytes` di atas adalah nama yang
dipakai loop chunk yang sudah ada; baca berkasnya dan pakai nama sebenarnya.
Begitu pula `ApiConfig.predictionUploads`: periksa nama konstantanya di
`fe/lib/config/api_config.dart`.

- [ ] **Step 3: Pemilih berkas di layar admin**

Di `fe/lib/screens/admin/news_management_screen.dart`, di samping pemilih gambar yang sudah ada, tambahkan pemilih video:

```dart
  Future<void> _pickVideo() async {
    // FileType.any, never FileType.custom: the extension list means three
    // different things across desktop, Android and mobile web, and on mobile
    // web a ZIP or MP4 reported as application/octet-stream simply greys out
    // and cannot be selected. The check happens here instead.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    if (!hasExtension(file.name, const ['mp4', 'webm'])) {
      _showMessage('Choose an MP4 or WebM file.');
      return;
    }

    if (file.bytes!.length > 50 * 1024 * 1024) {
      _showMessage('That video is larger than 50 MB.');
      return;
    }

    setState(() {
      _videoBytes = file.bytes;
      _videoName = file.name;
    });
  }
```

**Periksa tanda tangan `hasExtension` di `fe/lib/utils/file_extension.dart`**
dan sesuaikan; ia sudah dipakai oleh layar unggah prediksi.

Tambahkan `Uint8List? _videoBytes;` dan `String? _videoName;` ke state, sebuah
tombol yang memanggil `_pickVideo`, sebuah `LinearProgressIndicator` yang
dikendalikan `onProgress`, dan panggil `uploadVideo` setelah post-nya disimpan —
video butuh `postId`, jadi ia menyusul, bukan berbarengan.

- [ ] **Step 4: Analisa dan test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 150 test lulus.

- [ ] **Step 5: Coba sungguhan**

Jalankan aplikasi sebagai admin, buat sebuah post, lampirkan berkas MP4 sungguhan ~10 MB, simpan, lalu buka landing page dan putar videonya. Geser ke tengah.

Ini satu-satunya langkah yang membuktikan seluruh rantai bekerja: unggah berpotongan, penyimpanan, penyajian, Range, dan pemutar. Test tidak menjangkau satu pun dari itu bersamaan.

- [ ] **Step 6: Commit**

```bash
git add fe/lib/services/news_service.dart fe/lib/screens/admin/news_management_screen.dart
git commit -m "Let an administrator attach a video to a post"
```

---

### Task 5: Tombol emoji

**Files:**
- Modify: `fe/pubspec.yaml` — tambah `emoji_picker_flutter`
- Modify: `fe/lib/widgets/message_bubbles.dart` — `MessageComposer`, baris 211-275
- Test: `be/tests/Feature/MessagingTest.php` (ditambah satu test)

**Interfaces:**
- Consumes: tidak ada.
- Produces: `MessageComposer` menampilkan tombol emoji; tidak ada API baru.

- [ ] **Step 1: Tulis test yang gagal — di backend**

Emoji melintasi jaringan dan basis data, dan di situlah ia bisa rusak. `be/config/database.php:56-57` sudah `utf8mb4`, tapi koleksi tabel bisa berbeda dari koleksi koneksi, dan "seharusnya bekerja" bukan bukti.

Tambahkan ke `be/tests/Feature/MessagingTest.php`:

```php
    /**
     * Emoji survive the round trip.
     *
     * config/database.php sets utf8mb4, but a table's collation can differ
     * from the connection's, and a four-byte character silently becoming "?"
     * is exactly the kind of thing nobody notices until a researcher sends
     * one.
     */
    public function test_an_emoji_survives_being_sent_and_read_back(): void
    {
        $token = $this->tokenFor('researcher@brin.go.id', 'password123');

        $body = 'Terima kasih 🙏 hasilnya bagus 🎉';

        $this->apiAs($token)
            ->postJson('/api/messages', ['body' => $body])
            ->assertCreated();

        $this->apiAs($token)->getJson('/api/messages')
            ->assertOk()
            ->assertJsonPath('data.messages.0.body', $body);
    }
```

**Sesuaikan email, rute, dan jalur JSON dengan yang benar-benar dipakai berkas
itu** — baca test di sekitarnya dan ikuti bentuknya, jangan mengarang.

- [ ] **Step 2: Jalankan test**

Run: `cd be && php artisan test --filter=MessagingTest`

Bila **lulus**, koleksi sudah benar dan tidak ada yang perlu diperbaiki — test itu tetap tinggal sebagai penjaga. Bila **gagal** dengan emoji jadi `?`, koleksi tabel `messages` bukan `utf8mb4`; tulis migrasi yang mengubahnya sebelum melanjutkan.

- [ ] **Step 3: Tambahkan paketnya**

Run: `cd fe && flutter pub add emoji_picker_flutter`

Expected: 8 paket bertambah termasuk `shared_preferences`, dan **`win32` tetap 5.15.0**. Bila `win32` naik, hentikan.

- [ ] **Step 4: Tombol dan panel di `MessageComposer`**

Di `fe/lib/widgets/message_bubbles.dart`, dalam `_MessageComposerState`, tambahkan:

```dart
  bool _emojiOpen = false;

  /// Insert at the cursor, not at the end. People put emoji in the middle of
  /// a sentence.
  void _insert(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final at = selection.start < 0 ? text.length : selection.start;

    final next = text.replaceRange(at, selection.end < 0 ? at : selection.end, emoji);

    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + emoji.length),
    );
  }

  void _toggleEmoji() {
    setState(() => _emojiOpen = !_emojiOpen);
    // The panel replaces the keyboard rather than fighting it for the
    // bottom of the screen.
    if (_emojiOpen) {
      FocusScope.of(context).unfocus();
    } else {
      _focus.requestFocus();
    }
  }
```

Di `build`, tambahkan tombol sebelum `Expanded(child: TextField(...))`:

```dart
            IconButton(
              icon: Icon(
                _emojiOpen
                    ? Icons.keyboard_outlined
                    : Icons.emoji_emotions_outlined,
              ),
              onPressed: widget.enabled ? _toggleEmoji : null,
              tooltip: _emojiOpen ? 'Keyboard' : 'Emoji',
            ),
```

Dan bungkus `Container` terluar dengan `Column` yang menaruh panel di bawahnya:

```dart
        if (_emojiOpen)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) => _insert(emoji.emoji),
              config: const Config(
                emojiViewConfig: EmojiViewConfig(backgroundColor: AppTheme.surface),
              ),
            ),
          ),
```

Tambahkan `import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';`.
**Periksa nama kelas konfigurasi pada versi yang benar-benar terpasang** —
API `Config` paket ini berubah antar versi mayor; jalankan
`flutter pub deps | grep emoji` dan baca contoh di `.pub-cache` bila
`flutter analyze` mengeluh.

Pastikan panelnya menutup saat kolom teks difokuskan: tambahkan pendengar
`_focus` di `initState` yang memasang `_emojiOpen = false` saat fokus didapat.

- [ ] **Step 5: Analisa, test, APK**

Run: `cd fe && flutter analyze && flutter test && flutter build apk --release`
Expected: analyze bersih, 150 test lulus, APK terbangun. Paket kedua, jadi APK diuji lagi.

- [ ] **Step 6: Commit**

```bash
git add fe/pubspec.yaml fe/pubspec.lock fe/lib/widgets/message_bubbles.dart be/tests/Feature/MessagingTest.php
git commit -m "Put an emoji button beside the message box"
```

---

### Task 6: Status pending

**Files:**
- Modify: `fe/lib/models/chat_message.dart`
- Modify: `fe/lib/widgets/message_bubbles.dart` — `MessageBubble`, ikon di baris 183-196
- Modify: `fe/lib/screens/messages/message_thread_screen.dart:104-118`
- Modify: `fe/lib/screens/messages/admin_conversation_screen.dart:97`
- Test: `fe/test/message_delivery_test.dart` (baru)

**Interfaces:**
- Consumes: tidak ada.
- Produces: `enum MessageDelivery { pending, sent, failed }`; `ChatMessage.delivery` (default `MessageDelivery.sent`); `ChatMessage.pending({required String body, required bool fromAdmin})`; `ChatMessage.copyWith({MessageDelivery? delivery})`.

- [ ] **Step 1: Tulis test yang gagal**

Berkas baru `fe/test/message_delivery_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/chat_message.dart';

void main() {
  test('a message from the server counts as sent', () {
    final message = ChatMessage.fromJson(const {
      'id': 4,
      'body': 'hello',
      'from_admin': false,
    });

    expect(message.delivery, MessageDelivery.sent);
  });

  test('an optimistic message is pending and carries no server id', () {
    final message = ChatMessage.pending(body: 'hello', fromAdmin: false);

    expect(message.delivery, MessageDelivery.pending);
    expect(message.body, 'hello');
    // Nothing on the server corresponds to it yet.
    expect(message.id, 0);
  });

  test('a pending message can be marked failed without losing its text', () {
    // The whole point: a send that fails must not eat what someone wrote.
    final failed = ChatMessage.pending(body: 'important', fromAdmin: false)
        .copyWith(delivery: MessageDelivery.failed);

    expect(failed.delivery, MessageDelivery.failed);
    expect(failed.body, 'important');
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/message_delivery_test.dart`
Expected: FAIL — `MessageDelivery` belum ada.

- [ ] **Step 3: Tambahkan keadaan kirim ke `ChatMessage`**

Di puncak `fe/lib/models/chat_message.dart`:

```dart
/// Where a message is between being typed and being read.
///
/// Client-side only: there is no column for this. `sent` and `read` are the
/// server's business — `messages.read_at` already carries the second — and
/// `pending` exists only while a POST is in flight.
enum MessageDelivery { pending, sent, failed }
```

Di kelas `ChatMessage`, tambahkan field dan konstruktor:

```dart
  /// Defaults to [MessageDelivery.sent]: anything the server handed us has,
  /// by definition, arrived.
  final MessageDelivery delivery;
```

Tambahkan `this.delivery = MessageDelivery.sent,` ke konstruktor `const`.

Lalu dua pembantu di akhir kelas:

```dart
  /// A bubble to show immediately, before the server has answered.
  ///
  /// `id` is 0 because nothing on the server corresponds to it yet; it is
  /// replaced wholesale by the real message when the POST returns.
  factory ChatMessage.pending({
    required String body,
    required bool fromAdmin,
  }) => ChatMessage(
    id: 0,
    body: body,
    fromAdmin: fromAdmin,
    createdAt: DateTime.now(),
    delivery: MessageDelivery.pending,
  );

  ChatMessage copyWith({MessageDelivery? delivery}) => ChatMessage(
    id: id,
    body: body,
    fromAdmin: fromAdmin,
    author: author,
    authorAvatarPath: authorAvatarPath,
    readAt: readAt,
    createdAt: createdAt,
    delivery: delivery ?? this.delivery,
  );
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/message_delivery_test.dart`
Expected: PASS, 3 test.

- [ ] **Step 5: Gelembung menunjukkan keadaannya**

Di `fe/lib/widgets/message_bubbles.dart`, ganti blok ikon di baris 183-196:

```dart
                        // Only on your own messages: whether *they* have read
                        // it is the question you actually have.
                        if (mine) ...[
                          const SizedBox(width: 4),
                          Icon(
                            switch (message.delivery) {
                              MessageDelivery.pending => Icons.schedule,
                              MessageDelivery.failed => Icons.error_outline,
                              MessageDelivery.sent => message.isRead
                                  ? Icons.done_all
                                  : Icons.done,
                            },
                            size: 13,
                            color: switch (message.delivery) {
                              MessageDelivery.pending => AppTheme.textMuted,
                              MessageDelivery.failed => AppTheme.error,
                              MessageDelivery.sent => message.isRead
                                  ? AppTheme.accent
                                  : AppTheme.textMuted,
                            },
                          ),
                        ],
```

- [ ] **Step 6: Layar periset menyisipkan gelembung lebih dulu**

Di `fe/lib/screens/messages/message_thread_screen.dart`, ganti `_send` di baris 104-118:

```dart
  Future<void> _send(String body) async {
    // The bubble appears before the round trip, so the thread reacts to
    // typing rather than to the network.
    final optimistic = ChatMessage.pending(body: body, fromAdmin: false);

    setState(() => _messages = [..._messages, optimistic]);
    _scrollToEnd();

    try {
      final message = await _service.send(body);
      if (!mounted) return;

      // Replaced wholesale rather than patched: the server's copy carries the
      // id, the timestamp and the author this one only guessed at.
      setState(() {
        _messages = [
          for (final m in _messages)
            if (identical(m, optimistic)) message else m,
        ];
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _messages = [
          for (final m in _messages)
            if (identical(m, optimistic))
              m.copyWith(delivery: MessageDelivery.failed)
            else
              m,
        ];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
      rethrow; // The composer puts the text back.
    }
  }
```

`identical` dan bukan perbandingan `id`: pesan optimistik punya `id` 0, dan dua di antaranya bisa hidup bersamaan bila seseorang mengetik cepat.

Tambahkan import `MessageDelivery` bila `chat_message.dart` belum diimpor di berkas itu.

- [ ] **Step 7: Layar admin, bentuk yang sama**

Di `fe/lib/screens/messages/admin_conversation_screen.dart`, terapkan pola yang sama pada `_send` di baris 97. Perbedaannya satu: `fromAdmin: true`.

Baca metode aslinya dan ikuti bentuknya — nama variabel daftar pesannya mungkin berbeda dari `_messages`.

- [ ] **Step 8: Analisa dan test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 153 test lulus.

- [ ] **Step 9: Coba sungguhan**

Jalankan aplikasi, kirim sebuah pesan, dan perhatikan ikon jam berubah jadi centang. Lalu matikan backend dan kirim lagi: gelembungnya harus jadi merah, teksnya harus kembali ke kolom ketik, dan tidak ada yang hilang.

Kasus kedua itu yang paling penting dan paling mudah dilewatkan.

- [ ] **Step 10: Commit**

```bash
git add fe/lib/models/chat_message.dart fe/lib/widgets/message_bubbles.dart fe/lib/screens/messages/message_thread_screen.dart fe/lib/screens/messages/admin_conversation_screen.dart fe/test/message_delivery_test.dart
git commit -m "Show a message as sending before the server has answered"
```

---

### Task 7: Catat dan centang

**Files:**
- Modify: `ARCHITECTURE.md` — daftar kolom `news_posts`, dan §7 bila ia menyebut tujuan unggah
- Modify: `API.md` — endpoint video dan tujuan unggah baru
- Modify: `CHANGELOG.md`
- Modify: `ROADMAP.md` §12 item B2

- [ ] **Step 1: Verifikasi penuh**

```bash
cd be && php artisan test
cd ../fe && flutter analyze
flutter test
flutter build apk --release
```

Catat angka yang benar-benar keluar.

- [ ] **Step 2: `ARCHITECTURE.md`**

Tambahkan `video_path`, `video_mime`, `video_size_bytes` ke daftar kolom `news_posts`, dengan satu kalimat bahwa video melewati mesin unggah berpotongan karena `post_max_size` adalah 8M.

- [ ] **Step 3: `API.md`**

Dokumentasikan `GET /news/{id}/video` dan tujuan `news_video` pada
`POST /predictions/uploads`, termasuk bahwa tujuan itu admin-only meski rutenya
tidak.

- [ ] **Step 4: `CHANGELOG.md`**

Di puncak, mengikuti bentuk entri yang ada. Sebutkan **mengapa** video menempuh
unggah berpotongan (413 yang diukur, bukan diduga), bahwa Range sudah bekerja
sehingga tidak ada kode yang ditulis untuknya, dan bahwa status *pending* tidak
menyentuh basis data.

- [ ] **Step 5: `ROADMAP.md`**

Ubah `- [ ] **B2 —` menjadi `- [x]`, dengan angka yang diamati dan daftar apa
yang **tidak** dikerjakan — termasuk bahwa unggah video tidak bisa melanjutkan
sesi yang terputus, dan bahwa berkasnya dimuat penuh ke RAM sebelum dikirim
(ROADMAP §11 sudah mencatat bentuk masalah yang sama untuk prediksi dan
training).

- [ ] **Step 6: Commit**

```bash
git add ARCHITECTURE.md API.md CHANGELOG.md ROADMAP.md
git commit -m "Record what part B2 changed and why"
```

---

## Catatan untuk pelaksana

**Task 1 dan 2 berurutan**; Task 2 memakai konstanta dan `hasVideo()` dari Task 1.
**Task 3 memerlukan Task 1** (payload), **Task 4 memerlukan Task 2 dan 3**.
**Task 5 dan 6 tidak bergantung pada apa pun di atas** dan boleh dikerjakan lebih
dulu bila backend sedang tidak bisa dijalankan.

**Tiga tempat rencana ini sengaja menyuruh Anda membaca dulu, bukan menyalin
buta:** tanda tangan `downloadFile` (Task 3 Step 6), nama metode `_api` dan
konstanta `ApiConfig` untuk loop chunk (Task 4 Step 2), dan nama kelas
konfigurasi `emoji_picker_flutter` (Task 5 Step 4). Ketiganya bergantung pada
kode atau versi paket yang tidak bisa dipastikan saat rencana ditulis.
Menebaknya akan menghasilkan kode yang tidak dikompilasi; membacanya memakan
satu menit.

**Hutang yang bertambah, dengan sadar:** loop chunk kini ada di tiga tempat
(`prediction_service.dart`, `researcher_training_service.dart`, dan
`news_service.dart`). ROADMAP §10 sudah mencatat dua yang pertama layak
disatukan. B2 tidak menyatukannya — menyatukan sambil menambah pemakai ketiga
akan mencampur dua perubahan dalam satu rangkaian commit — tetapi B2 juga tidak
boleh berpura-pura salinan ketiga itu gratis.
