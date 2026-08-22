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

        $this->uploadVideo($bytes);

        $this->post->refresh();
        $this->assertTrue($this->post->hasVideo());
        $this->assertSame('video/mp4', $this->post->video_mime);
        $this->assertSame(strlen($bytes), (int) $this->post->video_size_bytes);
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

        $this->sendChunk($uploadId, $bytes);

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

        $this->uploadVideo($bytes);
        $this->post->refresh();
        $oldPath = $this->post->video_path;

        $this->uploadVideo($bytes);
        $this->post->refresh();

        $this->assertNotSame($oldPath, $this->post->video_path);
        $this->assertFalse(Storage::exists($oldPath));
        $this->assertTrue(Storage::exists($this->post->video_path));
    }

    /**
     * The real contract, copied from ChunkedUploadTest: a multipart POST
     * carrying `_method: PATCH`, an offset, and the chunk as a file.
     *
     * A raw PATCH body loses the Authorization header — passing an explicit
     * server array to `call()` replaces the one `apiAs()` set, and the
     * request arrives unauthenticated.
     */
    private function sendChunk(string $uploadId, string $bytes): void
    {
        $this->apiAs($this->token($this->admin))
            ->post(
                "/api/predictions/uploads/{$uploadId}",
                [
                    '_method' => 'PATCH',
                    'offset' => 0,
                    'chunk' => UploadedFile::fake()->createWithContent('chunk', $bytes),
                ],
                ['Accept' => 'application/json']
            )
            ->assertOk();
    }

    private function uploadVideo(string $bytes): void
    {
        $uploadId = $this->start($this->admin, ['total_size' => strlen($bytes)])
            ->assertCreated()
            ->json('data.upload_id');

        $this->sendChunk($uploadId, $bytes);

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
