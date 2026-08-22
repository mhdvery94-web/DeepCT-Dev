<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * What `phone` is, stated as tests so it cannot quietly become something else.
 *
 * `username` was NOT NULL and unique, so every account creation had to invent
 * one. `phone` answers the question that actually comes up — how do I reach
 * this researcher — and gets out of the way when nobody knows the answer yet.
 */
class UserPhoneTest extends TestCase
{
    use RefreshDatabase;

    private function user(array $overrides = []): User
    {
        return User::create(array_merge([
            'name' => 'Researcher',
            'email' => 'r' . uniqid() . '@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'is_active' => true,
        ], $overrides));
    }

    public function test_an_account_can_exist_without_a_phone_number(): void
    {
        $user = $this->user();

        $this->assertNull($user->fresh()->phone);
    }

    /**
     * The whole point of the change. A shared office line, or two researchers
     * on one handset, must not stop the second account being created — which
     * is exactly what `username` being unique did.
     */
    public function test_two_accounts_may_share_one_phone_number(): void
    {
        $this->user(['phone' => '+62 812 3456 7890']);
        $second = $this->user(['phone' => '+62 812 3456 7890']);

        $this->assertSame('+62 812 3456 7890', $second->fresh()->phone);
        $this->assertSame(2, User::where('phone', '+62 812 3456 7890')->count());
    }

    public function test_a_phone_number_travels_with_the_user_payload(): void
    {
        $user = $this->user(['phone' => '08123456789']);

        $this->assertArrayHasKey('phone', $user->toPublicArray());
        $this->assertSame('08123456789', $user->toPublicArray()['phone']);
    }

    private function admin(): User
    {
        return $this->user([
            'name' => 'Admin',
            'email' => 'admin@brin.go.id',
            'role' => 'admin',
        ]);
    }

    public function test_an_administrator_can_create_an_account_with_a_phone(): void
    {
        $admin = $this->admin();
        $token = $this->tokenFor($admin->email, 'password123');

        $this->apiAs($token)->postJson('/api/admin/users', [
            'name' => 'New Researcher',
            'email' => 'new@brin.go.id',
            'phone' => '0812 3456 7890',
            'role' => 'user',
        ])->assertCreated();

        $this->assertSame(
            '0812 3456 7890',
            User::where('email', 'new@brin.go.id')->first()->phone
        );
    }

    public function test_an_administrator_can_create_an_account_without_a_phone(): void
    {
        $admin = $this->admin();
        $token = $this->tokenFor($admin->email, 'password123');

        $this->apiAs($token)->postJson('/api/admin/users', [
            'name' => 'No Phone',
            'email' => 'nophone@brin.go.id',
            'role' => 'user',
        ])->assertCreated();

        $this->assertNull(User::where('email', 'nophone@brin.go.id')->first()->phone);
    }

    public function test_users_can_be_searched_by_phone_number(): void
    {
        $admin = $this->admin();
        $this->user(['name' => 'Findable', 'phone' => '081299998888']);
        $this->user(['name' => 'Unrelated', 'phone' => '081200001111']);

        $token = $this->tokenFor($admin->email, 'password123');

        $this->apiAs($token)->getJson('/api/admin/users?search=99998888')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Findable');
    }

    /**
     * Approving a request used to call `uniqueUsername(suggestedUsername())`,
     * two methods whose only job was inventing a value for a column nobody
     * read. Both are gone; this asserts the path still works without them.
     */
    public function test_approving_an_access_request_creates_an_account(): void
    {
        $admin = $this->admin();
        $token = $this->tokenFor($admin->email, 'password123');

        $request = \App\Models\AccessRequest::create([
            'first_name' => 'Ayu',
            'last_name' => 'Pratiwi',
            'email' => 'ayu@brin.go.id',
            'institution' => 'BRIN',
            'reason' => 'Neutron CT research',
            'status' => 'pending',
        ]);

        $this->apiAs($token)
            ->postJson("/api/admin/access-requests/{$request->id}/approve", [])
            ->assertOk();

        $created = User::where('email', 'ayu@brin.go.id')->first();
        $this->assertNotNull($created);
        $this->assertNull($created->phone);
    }
}
