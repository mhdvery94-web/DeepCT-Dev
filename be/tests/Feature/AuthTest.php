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
     * One session per account: a second login while the account is genuinely
     * in use is refused, rather than silently kicking the first device off.
     */
    public function test_a_second_login_is_refused_while_the_account_is_in_use(): void
    {
        $user = $this->makeUser();

        $first = $this->tokenFor('researcher@brin.go.id', 'user123');
        $this->apiAs($first)->getJson('/api/user')->assertOk();

        $response = $this->postJson('/api/login', [
            'email' => 'researcher@brin.go.id',
            'password' => 'user123',
        ]);

        $response->assertStatus(409)
            ->assertJsonPath('success', false);

        $this->assertStringContainsString(
            'already signed in',
            $response->json('message')
        );

        // The device already holding a session must keep working.
        $this->apiAs($first)->getJson('/api/user')->assertOk();
        $this->assertSame(1, $user->tokens()->count());
    }

    /** The rule applies to administrators too, not just researchers. */
    public function test_an_admin_is_refused_a_second_login_as_well(): void
    {
        $this->makeUser([
            'username' => 'admin',
            'email' => 'admin@brin.go.id',
            'role' => 'admin',
        ]);

        $this->tokenFor('admin@brin.go.id', 'user123');

        $this->postJson('/api/login', [
            'email' => 'admin@brin.go.id',
            'password' => 'user123',
        ])->assertStatus(409);
    }

    /**
     * The safety valve. A session nobody logged out of -- app force-closed,
     * browser shut, phone dead -- must not lock the account until the token
     * expires seven days later.
     */
    public function test_an_abandoned_session_can_be_taken_over(): void
    {
        $user = $this->makeUser();

        $stale = $this->tokenFor('researcher@brin.go.id', 'user123');

        // Nobody has touched that token for longer than the idle window.
        $user->tokens()->update([
            'last_used_at' => now()->subMinutes(30),
            'created_at' => now()->subMinutes(30),
        ]);

        $this->postJson('/api/login', [
            'email' => 'researcher@brin.go.id',
            'password' => 'user123',
        ])->assertOk();

        $this->assertSame(1, $user->tokens()->count(), 'the stale token is cleared');
        $this->apiAs($stale)->getJson('/api/user')->assertUnauthorized();
    }

    /** Logging out properly frees the account immediately. */
    public function test_logging_out_allows_an_immediate_new_login(): void
    {
        $this->makeUser();

        $token = $this->tokenFor('researcher@brin.go.id', 'user123');
        $this->apiAs($token)->postJson('/api/logout')->assertOk();

        $this->postJson('/api/login', [
            'email' => 'researcher@brin.go.id',
            'password' => 'user123',
        ])->assertOk();
    }

    /**
     * Using the app keeps the session alive: Sanctum stamps last_used_at on
     * every authenticated request, so an idle window must not expire under an
     * active user.
     */
    public function test_activity_keeps_a_session_from_being_taken_over(): void
    {
        $user = $this->makeUser();

        $token = $this->tokenFor('researcher@brin.go.id', 'user123');

        // Backdate, then use the token: last_used_at moves back to now.
        $user->tokens()->update([
            'last_used_at' => now()->subMinutes(30),
            'created_at' => now()->subMinutes(30),
        ]);
        $this->apiAs($token)->getJson('/api/user')->assertOk();

        $this->postJson('/api/login', [
            'email' => 'researcher@brin.go.id',
            'password' => 'user123',
        ])->assertStatus(409);
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
