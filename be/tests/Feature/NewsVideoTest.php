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
    public function test_removing_only_video_preserves_image_and_article(): void
    {
        $post = $this->postWithVideo();
        $videoPath = $post->video_path;
        Storage::put('news/kept-image.png', 'kept image');
        $post->update(['image_path' => 'news/kept-image.png', 'image_mime' => 'image/png', 'body' => 'Kept research content']);
        $token = $this->tokenFor($this->admin->email, 'password123');

        $this->apiAs($token)->postJson("/api/admin/news/{$post->id}", ['remove_video' => true])
            ->assertOk()->assertJsonPath('data.has_video', false)
            ->assertJsonPath('data.has_image', true)
            ->assertJsonPath('data.body', 'Kept research content');
        $this->assertFalse(Storage::exists($videoPath));
        $this->assertTrue(Storage::exists('news/kept-image.png'));
        $this->assertNull($post->fresh()->video_path);
        $this->assertNull($post->fresh()->video_mime);
        $this->assertNull($post->fresh()->video_size_bytes);

        // Repeating removal is safe; malformed controls fail validation.
        $this->apiAs($token)->postJson("/api/admin/news/{$post->id}", ['remove_video' => true])->assertOk();
        $this->apiAs($token)->postJson("/api/admin/news/{$post->id}", ['remove_video' => 'invalid'])
            ->assertUnprocessable()->assertJsonValidationErrors('remove_video');
    }

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
