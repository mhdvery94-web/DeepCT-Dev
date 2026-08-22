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
}
