<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Profile photos.
 *
 * What matters: a researcher may only change their own, an administrator may
 * change anyone's, the upload guard reads the file rather than its name, and
 * an account with no photo says so plainly instead of being served something.
 */
class AvatarTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $researcher;
    private User $otherResearcher;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('local');

        $this->admin = $this->makeUser('admin', 'admin@brin.go.id', 'admin');
        $this->researcher = $this->makeUser('researcher', 'researcher@brin.go.id', 'user');
        $this->otherResearcher = $this->makeUser('other', 'other@brin.go.id', 'user');
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

    /** A real PNG. `UploadedFile::fake()->image()` needs GD, which is absent. */
    private function pngFile(string $name = 'me.png'): UploadedFile
    {
        $signature = chr(137) . 'PNG' . chr(13) . chr(10) . chr(26) . chr(10);

        $ihdr = pack('N', 13) . 'IHDR'
            . pack('NN', 1, 1) . chr(8) . chr(0) . chr(0) . chr(0) . chr(0);
        $ihdr .= pack('N', crc32(substr($ihdr, 4)));

        $idatData = 'IDAT' . gzcompress(chr(0) . chr(0));
        $idat = pack('N', strlen($idatData) - 4) . $idatData
            . pack('N', crc32($idatData));

        $iend = pack('N', 0) . 'IEND' . pack('N', crc32('IEND'));

        $path = tempnam(sys_get_temp_dir(), 'avatar') . '.png';
        file_put_contents($path, $signature . $ihdr . $idat . $iend);

        return new UploadedFile($path, $name, 'image/png', null, true);
    }

    /** Multipart POST that asks for JSON, so a 422 is not a 302 redirect. */
    private function postForm(string $uri, array $data = [])
    {
        return $this->post($uri, $data, ['Accept' => 'application/json']);
    }

    // -------------------------------------------------------- own photo

    public function test_a_researcher_can_set_their_own_photo(): void
    {
        $response = $this->apiAs($this->tokenAs($this->researcher))
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile()]);

        $response->assertOk()->assertJsonPath(
            'data.avatar_url',
            "/users/{$this->researcher->id}/avatar"
        );

        $fresh = $this->researcher->fresh();
        $this->assertNotNull($fresh->avatar_path);
        Storage::assertExists($fresh->avatar_path);
    }

    public function test_setting_a_photo_is_recorded_in_the_audit_trail(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile()])
            ->assertOk();

        $this->assertDatabaseHas('user_activities', [
            'user_id' => $this->researcher->id,
            'activity_type' => 'profile_updated',
        ]);
    }

    public function test_replacing_a_photo_removes_the_old_file(): void
    {
        $token = $this->tokenAs($this->researcher);

        $this->apiAs($token)
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile('one.png')])
            ->assertOk();
        $first = $this->researcher->fresh()->avatar_path;

        $this->apiAs($token)
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile('two.png')])
            ->assertOk();
        $second = $this->researcher->fresh()->avatar_path;

        $this->assertNotSame($first, $second);
        Storage::assertMissing($first);
        Storage::assertExists($second);
    }

    public function test_a_researcher_can_remove_their_own_photo(): void
    {
        $token = $this->tokenAs($this->researcher);

        $this->apiAs($token)
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile()])
            ->assertOk();
        $path = $this->researcher->fresh()->avatar_path;

        $this->apiAs($token)
            ->deleteJson('/api/me/avatar')
            ->assertOk()
            ->assertJsonPath('data.avatar_url', null);

        Storage::assertMissing($path);
        $this->assertNull($this->researcher->fresh()->avatar_path);
    }

    // -------------------------------------------------------- validation

    public function test_a_file_that_is_not_an_image_is_refused(): void
    {
        // A real file, not `UploadedFile::fake()`, which reports its mime type
        // from the extension and would sail past the rule under test.
        $path = tempnam(sys_get_temp_dir(), 'avatar') . '.png';
        file_put_contents($path, '<?php echo "hello"; ?>');

        $this->apiAs($this->tokenAs($this->researcher))
            ->postForm('/api/me/avatar', [
                'avatar' => new UploadedFile($path, 'evil.png', 'image/png', null, true),
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['avatar']);

        $this->assertNull($this->researcher->fresh()->avatar_path);
    }

    public function test_the_photo_field_is_required(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postForm('/api/me/avatar', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['avatar']);
    }

    // ----------------------------------------------------------- serving

    public function test_a_photo_is_visible_to_any_signed_in_account(): void
    {
        // Avatars appear beside activity logs and in the user list, so a
        // researcher has to be able to load a colleague's.
        $this->apiAs($this->tokenAs($this->researcher))
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile()])
            ->assertOk();

        $this->apiAs($this->tokenAs($this->otherResearcher))
            ->get("/api/users/{$this->researcher->id}/avatar")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png');
    }

    public function test_a_photo_is_not_served_to_a_stranger(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile()])
            ->assertOk();

        // With the Accept header: without it Laravel's auth middleware tries
        // to redirect to a `login` route that a JSON API does not have, and
        // the failure is "Route [login] not defined" rather than a 401.
        $this->apiAs(null)
            ->get(
                "/api/users/{$this->researcher->id}/avatar",
                ['Accept' => 'application/json'],
            )
            ->assertUnauthorized();
    }

    public function test_an_account_with_no_photo_returns_404(): void
    {
        // 404, not a stock image: the client draws the initials frame, and a
        // server-side placeholder would be a second opinion on what "no photo"
        // looks like.
        $this->apiAs($this->tokenAs($this->researcher))
            ->get("/api/users/{$this->otherResearcher->id}/avatar")
            ->assertNotFound();
    }

    // ------------------------------------------------------------- admin

    public function test_an_admin_can_replace_someone_elses_photo(): void
    {
        // Somebody has to be able to take down an inappropriate photo.
        $this->apiAs($this->tokenAs($this->admin))
            ->postForm(
                "/api/admin/users/{$this->researcher->id}/avatar",
                ['avatar' => $this->pngFile()]
            )
            ->assertOk();

        $this->assertNotNull($this->researcher->fresh()->avatar_path);
    }

    public function test_an_admin_can_remove_someone_elses_photo(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile()])
            ->assertOk();
        $path = $this->researcher->fresh()->avatar_path;

        $this->apiAs($this->tokenAs($this->admin))
            ->deleteJson("/api/admin/users/{$this->researcher->id}/avatar")
            ->assertOk();

        Storage::assertMissing($path);
        $this->assertNull($this->researcher->fresh()->avatar_path);
    }

    public function test_a_researcher_cannot_change_someone_elses_photo(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postForm(
                "/api/admin/users/{$this->otherResearcher->id}/avatar",
                ['avatar' => $this->pngFile()]
            )
            ->assertForbidden();

        $this->assertNull($this->otherResearcher->fresh()->avatar_path);
    }

    // ------------------------------------------------------------ payload

    public function test_every_user_payload_carries_the_photo_url(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile()])
            ->assertOk();

        $expected = "/users/{$this->researcher->id}/avatar";

        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/user')
            ->assertOk()
            ->assertJsonPath('data.avatar_url', $expected);

        $listed = $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/users')
            ->assertOk()
            ->json('data');

        $row = collect($listed)->firstWhere('id', $this->researcher->id);
        $this->assertSame($expected, $row['avatar_url']);
    }

    public function test_the_payload_never_exposes_where_the_file_lives(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postForm('/api/me/avatar', ['avatar' => $this->pngFile()])
            ->assertOk();

        $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/users')
            ->assertOk()
            ->assertJsonMissingPath('data.0.avatar_path')
            ->assertJsonMissingPath('data.0.avatar_mime');
    }

    public function test_an_account_without_a_photo_reports_a_null_url(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/user')
            ->assertOk()
            ->assertJsonPath('data.avatar_url', null);
    }
}
