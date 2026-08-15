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
 * Research news.
 *
 * The assertions that matter are the publish switch — a draft must be
 * invisible to the public, photo included — and the upload guard, since
 * nothing on this machine can re-encode an image it should not have accepted.
 */
class NewsPostTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $researcher;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('local');

        $this->admin = $this->makeUser('admin', 'admin@brin.go.id', 'admin');
        $this->researcher = $this->makeUser('researcher', 'researcher@brin.go.id', 'user');
    }

    private function makeUser(string $username, string $email, string $role): User
    {
        return User::create([
            'username' => $username,
            'name' => ucfirst($username),
            'email' => $email,
            'password' => Hash::make('password123'),
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function tokenAs(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    /**
     * A real PNG, built byte by byte.
     *
     * `UploadedFile::fake()->image()` needs GD, which this machine does not
     * have — the same limitation that stops the application resizing uploads.
     */
    private function pngFile(string $name = 'photo.png'): UploadedFile
    {
        $signature = chr(137) . 'PNG' . chr(13) . chr(10) . chr(26) . chr(10);

        $ihdr = pack('N', 13) . 'IHDR'
            . pack('NN', 1, 1) . chr(8) . chr(0) . chr(0) . chr(0) . chr(0);
        $ihdr .= pack('N', crc32(substr($ihdr, 4)));

        $raw = chr(0) . chr(0);
        $idatData = 'IDAT' . gzcompress($raw);
        $idat = pack('N', strlen($idatData) - 4) . $idatData
            . pack('N', crc32($idatData));

        $iend = pack('N', 0) . 'IEND' . pack('N', crc32('IEND'));

        $path = tempnam(sys_get_temp_dir(), 'news') . '.png';
        file_put_contents($path, $signature . $ihdr . $idat . $iend);

        return new UploadedFile($path, $name, 'image/png', null, true);
    }

    /**
     * A multipart POST that asks for JSON back.
     *
     * `postJson` cannot carry a file, and a plain `post` without the Accept
     * header makes Laravel answer a failed validation with a 302 redirect
     * instead of 422 — which reads as a mysterious "expected 422, got 302".
     */
    private function postForm(string $uri, array $data = [])
    {
        return $this->post($uri, $data, ['Accept' => 'application/json']);
    }

    private function createPost(array $overrides = []): NewsPost
    {
        return NewsPost::create(array_merge([
            'title' => 'Neutron imaging beamline upgraded',
            'summary' => 'The detector was replaced over the shutdown.',
            'is_published' => true,
            'published_at' => now(),
            'created_by' => $this->admin->id,
        ], $overrides));
    }

    // ------------------------------------------------------------- public

    public function test_the_public_list_shows_published_posts(): void
    {
        $this->createPost(['title' => 'Visible']);

        $this->getJson('/api/news')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.title', 'Visible');
    }

    public function test_a_draft_is_invisible_to_the_public(): void
    {
        $this->createPost([
            'title' => 'Not ready',
            'is_published' => false,
            'published_at' => null,
        ]);

        $this->getJson('/api/news')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_the_public_payload_never_leaks_the_draft_flag(): void
    {
        $this->createPost();

        $this->getJson('/api/news')
            ->assertOk()
            ->assertJsonMissingPath('data.0.is_published');
    }

    public function test_posts_come_back_in_slide_order(): void
    {
        $this->createPost(['title' => 'Third', 'sort_order' => 3]);
        $this->createPost(['title' => 'First', 'sort_order' => 1]);
        $this->createPost(['title' => 'Second', 'sort_order' => 2]);

        $titles = $this->getJson('/api/news')->assertOk()->json('data.*.title');

        $this->assertSame(['First', 'Second', 'Third'], $titles);
    }

    // -------------------------------------------------------------- photo

    public function test_an_admin_can_publish_a_post_with_a_photo(): void
    {
        $response = $this->apiAs($this->tokenAs($this->admin))
            ->postForm('/api/admin/news', [
                'title' => 'New sample stage',
                'summary' => 'Rotation is now motorised.',
                'is_published' => '1',
                'image' => $this->pngFile(),
            ]);

        $response->assertCreated()
            ->assertJsonPath('data.has_image', true)
            ->assertJsonPath('data.is_published', true);

        $post = NewsPost::firstOrFail();
        $this->assertNotNull($post->image_path);
        Storage::assertExists($post->image_path);
    }

    public function test_the_photo_of_a_published_post_is_public(): void
    {
        $this->apiAs($this->tokenAs($this->admin))
            ->postForm('/api/admin/news', [
                'title' => 'New sample stage',
                'summary' => 'Rotation is now motorised.',
                'is_published' => '1',
                'image' => $this->pngFile(),
            ])->assertCreated();

        $id = NewsPost::firstOrFail()->id;

        $this->apiAs(null)
            ->get("/api/news/{$id}/image")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png');
    }

    public function test_the_photo_of_a_draft_is_not_public(): void
    {
        // A draft that could be read by guessing an id would leak an
        // unannounced result before it is meant to be seen.
        $this->apiAs($this->tokenAs($this->admin))
            ->postForm('/api/admin/news', [
                'title' => 'Embargoed',
                'summary' => 'Not announced yet.',
                'image' => $this->pngFile(),
            ])->assertCreated();

        $id = NewsPost::firstOrFail()->id;

        // apiAs(null), not a bare get(): the Authorization header set by the
        // call above survives for the rest of the method, so a plain request
        // would still arrive as the administrator.
        $this->apiAs(null)->get("/api/news/{$id}/image")->assertNotFound();
    }

    public function test_an_admin_can_preview_the_photo_of_a_draft(): void
    {
        $this->apiAs($this->tokenAs($this->admin))
            ->postForm('/api/admin/news', [
                'title' => 'Embargoed',
                'summary' => 'Not announced yet.',
                'image' => $this->pngFile(),
            ])->assertCreated();

        $id = NewsPost::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->get("/api/news/{$id}/image")
            ->assertOk();
    }

    public function test_a_file_that_is_not_an_image_is_refused(): void
    {
        // A real file, not `UploadedFile::fake()`: the fake reports its mime
        // type from the *extension*, so it would sail through the check this
        // test exists to prove. The rule is `mimetypes:`, which reads the
        // file's actual bytes.
        $path = tempnam(sys_get_temp_dir(), 'news') . '.png';
        file_put_contents($path, '<?php echo "hello"; ?>');

        $response = $this->apiAs($this->tokenAs($this->admin))
            ->postForm('/api/admin/news', [
                'title' => 'Payload',
                'summary' => 'Trying to upload a script.',
                'image' => new UploadedFile($path, 'evil.png', 'image/png', null, true),
            ]);

        $response->assertStatus(422)->assertJsonValidationErrors(['image']);
        $this->assertSame(0, NewsPost::count());
    }

    public function test_replacing_the_photo_removes_the_old_file(): void
    {
        $token = $this->tokenAs($this->admin);

        $this->apiAs($token)->postForm('/api/admin/news', [
            'title' => 'First photo',
            'summary' => 'One.',
            'image' => $this->pngFile('one.png'),
        ])->assertCreated();

        $post = NewsPost::firstOrFail();
        $original = $post->image_path;

        $this->apiAs($token)->postForm("/api/admin/news/{$post->id}", [
            'image' => $this->pngFile('two.png'),
        ])->assertOk();

        $replaced = $post->fresh()->image_path;

        $this->assertNotSame($original, $replaced);
        Storage::assertMissing($original);
        Storage::assertExists($replaced);
    }

    public function test_removing_the_photo_leaves_the_post(): void
    {
        $token = $this->tokenAs($this->admin);

        $this->apiAs($token)->postForm('/api/admin/news', [
            'title' => 'With photo',
            'summary' => 'One.',
            'image' => $this->pngFile(),
        ])->assertCreated();

        $post = NewsPost::firstOrFail();
        $path = $post->image_path;

        $this->apiAs($token)
            ->postForm("/api/admin/news/{$post->id}", ['remove_image' => '1'])
            ->assertOk()
            ->assertJsonPath('data.has_image', false);

        Storage::assertMissing($path);
        $this->assertNull($post->fresh()->image_path);
    }

    public function test_deleting_a_post_deletes_its_photo(): void
    {
        $token = $this->tokenAs($this->admin);

        $this->apiAs($token)->postForm('/api/admin/news', [
            'title' => 'Temporary',
            'summary' => 'One.',
            'image' => $this->pngFile(),
        ])->assertCreated();

        $post = NewsPost::firstOrFail();
        $path = $post->image_path;

        $this->apiAs($token)
            ->deleteJson("/api/admin/news/{$post->id}")
            ->assertOk();

        Storage::assertMissing($path);
        $this->assertSame(0, NewsPost::count());
    }

    // -------------------------------------------------------------- admin

    public function test_the_toggle_switches_a_post_on_and_off(): void
    {
        $post = $this->createPost(['is_published' => false, 'published_at' => null]);
        $token = $this->tokenAs($this->admin);

        $this->apiAs($token)
            ->patchJson("/api/admin/news/{$post->id}/toggle")
            ->assertOk()
            ->assertJsonPath('data.is_published', true);

        $this->assertNotNull($post->fresh()->published_at);

        $this->apiAs($token)
            ->patchJson("/api/admin/news/{$post->id}/toggle")
            ->assertOk()
            ->assertJsonPath('data.is_published', false);

        $this->getJson('/api/news')->assertJsonCount(0, 'data');
    }

    public function test_re_publishing_keeps_the_original_publish_date(): void
    {
        // Otherwise hiding and re-showing an old post would jump it to the
        // front of a slideshow ordered by date.
        $post = $this->createPost(['published_at' => now()->subDays(30)]);
        $original = $post->published_at;
        $token = $this->tokenAs($this->admin);

        $this->apiAs($token)->patchJson("/api/admin/news/{$post->id}/toggle");
        $this->apiAs($token)->patchJson("/api/admin/news/{$post->id}/toggle");

        $this->assertTrue($original->equalTo($post->fresh()->published_at));
    }

    public function test_the_admin_list_shows_drafts_and_counts_them(): void
    {
        $this->createPost(['title' => 'Live']);
        $this->createPost([
            'title' => 'Draft',
            'is_published' => false,
            'published_at' => null,
        ]);

        $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/news')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.published_count', 1)
            ->assertJsonPath('meta.draft_count', 1);
    }

    public function test_a_post_needs_a_title_and_a_summary(): void
    {
        $this->apiAs($this->tokenAs($this->admin))
            ->postJson('/api/admin/news', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['title', 'summary']);
    }

    public function test_a_researcher_cannot_touch_the_news(): void
    {
        $post = $this->createPost();
        $token = $this->tokenAs($this->researcher);

        $this->apiAs($token)->getJson('/api/admin/news')->assertForbidden();
        $this->apiAs($token)->postJson('/api/admin/news', [
            'title' => 'Mine now',
            'summary' => 'Hello.',
        ])->assertForbidden();
        $this->apiAs($token)
            ->patchJson("/api/admin/news/{$post->id}/toggle")
            ->assertForbidden();
        $this->apiAs($token)
            ->deleteJson("/api/admin/news/{$post->id}")
            ->assertForbidden();
    }
}
