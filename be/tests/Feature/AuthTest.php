<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserActivity;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    private function makeUser(array $overrides = []): User
    {
        return User::create(array_merge([
            'username' => 'researcher',
            'name' => 'Dr. Sample Researcher',
            'email' => 'researcher@brin.go.id',
            'password' => Hash::make('user123'),
            'role' => 'user',
            'is_active' => true,
        ], $overrides));
    }

    public function test_login_returns_a_token(): void
    {
        $this->makeUser();

        $response = $this->postJson('/api/login', [
            'email' => 'researcher@brin.go.id',
            'password' => 'user123',
        ]);

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['token', 'user' => ['id', 'role']]]);

        $this->assertNotEmpty($response->json('data.token'));
    }

    public function test_login_rejects_a_wrong_password(): void
    {
        $this->makeUser();

        $this->postJson('/api/login', [
            'email' => 'researcher@brin.go.id',
            'password' => 'not-the-password',
        ])->assertStatus(422);
    }

    /**
     * A deactivated account gets its own message rather than "credentials are
     * incorrect", so the researcher knows to contact an administrator instead
     * of retyping their password.
     */
    public function test_login_tells_a_deactivated_user_what_is_wrong(): void
    {
        $this->makeUser(['is_active' => false]);

        $response = $this->postJson('/api/login', [
            'email' => 'researcher@brin.go.id',
            'password' => 'user123',
        ]);

        $response->assertStatus(422);
        $this->assertStringContainsString(
            'deactivated',
            $response->json('errors.email.0') ?? ''
        );
    }

    /**
     * Concurrent sessions are allowed. A researcher on a laptop and a phone
     * holds two tokens, and signing in on one must not disturb the other.
     */
    public function test_two_devices_can_be_signed_in_at_once(): void
    {
        $user = $this->makeUser();

        $laptop = $this->tokenFor('researcher@brin.go.id', 'user123');
        $phone = $this->tokenFor('researcher@brin.go.id', 'user123');

        $this->assertNotSame($laptop, $phone, 'each login gets its own token');
        $this->assertSame(2, $user->tokens()->count());

        $this->apiAs($laptop)->getJson('/api/user')->assertOk();
        $this->apiAs($phone)->getJson('/api/user')->assertOk();
    }

    public function test_an_admin_can_also_hold_several_sessions(): void
    {
        $admin = $this->makeUser([
            'username' => 'admin',
            'email' => 'admin@brin.go.id',
            'role' => 'admin',
        ]);

        $first = $this->tokenFor('admin@brin.go.id', 'user123');
        $second = $this->tokenFor('admin@brin.go.id', 'user123');

        $this->assertSame(2, $admin->tokens()->count());
        $this->apiAs($first)->getJson('/api/user')->assertOk();
        $this->apiAs($second)->getJson('/api/user')->assertOk();
    }

    /** Signing out on one device must not sign the others out. */
    public function test_logging_out_on_one_device_leaves_the_others_alone(): void
    {
        $user = $this->makeUser();

        $laptop = $this->tokenFor('researcher@brin.go.id', 'user123');
        $phone = $this->tokenFor('researcher@brin.go.id', 'user123');

        $this->apiAs($laptop)->postJson('/api/logout')->assertOk();

        $this->apiAs($laptop)->getJson('/api/user')->assertUnauthorized();
        $this->apiAs($phone)->getJson('/api/user')->assertOk();

        $this->assertSame(1, $user->tokens()->count());
    }

    public function test_logout_revokes_the_current_token(): void
    {
        $this->makeUser();

        $token = $this->postJson('/api/login', [
            'email' => 'researcher@brin.go.id',
            'password' => 'user123',
        ])->json('data.token');

        $this->apiAs($token)->postJson('/api/logout')->assertOk();

        $this->apiAs($token)->getJson('/api/user')->assertUnauthorized();
    }

    public function test_login_and_logout_are_recorded_in_the_audit_trail(): void
    {
        $user = $this->makeUser();

        $token = $this->postJson('/api/login', [
            'email' => 'researcher@brin.go.id',
            'password' => 'user123',
        ])->json('data.token');

        $this->apiAs($token)->postJson('/api/logout');

        $types = UserActivity::where('user_id', $user->id)
            ->pluck('activity_type')
            ->all();

        $this->assertContains('login', $types);
        $this->assertContains('logout', $types);
    }

    public function test_protected_routes_reject_an_anonymous_caller(): void
    {
        foreach (['/api/user', '/api/me/stats', '/api/predictions'] as $route) {
            $this->getJson($route)->assertUnauthorized();
        }
    }

    public function test_health_endpoint_is_public(): void
    {
        $this->getJson('/api/health')->assertOk()->assertJsonPath('success', true);
    }
}
