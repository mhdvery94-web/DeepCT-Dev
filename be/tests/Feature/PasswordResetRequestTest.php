<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PasswordResetRequestTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::create([
            'name' => 'Researcher', 'email' => 'researcher@reset.test',
            'phone' => '+62 (812) 3456-7890',
            'password' => Hash::make('original-test-password'),
            'role' => 'user', 'is_active' => true,
        ]);
    }

    public function test_matching_email_and_formatted_phone_submit_a_review_without_resetting_credentials(): void
    {
        $this->user->createToken('existing-session');
        $this->postJson('/api/password-reset-requests', [
            'email' => 'RESEARCHER@reset.test', 'phone' => '0812 3456 7890',
        ])->assertCreated()->assertJsonPath('success', true);
        $this->assertSame(1, Conversation::whereNull('user_id')->count());
        $this->assertSame(1, Message::count());
        $this->assertStringContainsString('Phone: 0812 3456 7890', Message::first()->body);
        $this->assertTrue(Hash::check('original-test-password', $this->user->fresh()->password));
        $this->assertSame(1, $this->user->tokens()->count());
    }

    public function test_unknown_email_or_mismatched_phone_reports_user_not_found(): void
    {
        foreach ([
            ['email' => 'unknown@reset.test', 'phone' => '+6281234567890'],
            ['email' => $this->user->email, 'phone' => '+6289999999999'],
        ] as $payload) {
            $this->postJson('/api/password-reset-requests', $payload)
                ->assertNotFound()->assertJsonPath('success', false)
                ->assertJsonPath('message', 'User not found. The email and phone number must match the same active account.');
        }
        $this->assertSame(0, Message::count());
    }

    public function test_email_and_phone_from_different_accounts_cannot_match(): void
    {
        User::create(['name' => 'Other', 'email' => 'other@reset.test', 'phone' => '+6289999999999', 'password' => bcrypt('test-password'), 'role' => 'user', 'is_active' => true]);
        $this->postJson('/api/password-reset-requests', ['email' => $this->user->email, 'phone' => '+6289999999999'])->assertNotFound();
        $this->assertSame(0, Conversation::count());
    }

    public function test_inactive_accounts_and_accounts_without_a_phone_cannot_match(): void
    {
        $this->user->update(['is_active' => false]);
        $this->postJson('/api/password-reset-requests', ['email' => $this->user->email, 'phone' => '+6281234567890'])->assertNotFound();
        $this->user->update(['is_active' => true, 'phone' => null]);
        $this->postJson('/api/password-reset-requests', ['email' => $this->user->email, 'phone' => '+6281234567890'])->assertNotFound();
    }

    public function test_both_fields_are_required_and_invalid_phone_is_rejected(): void
    {
        $this->postJson('/api/password-reset-requests', [])->assertUnprocessable()->assertJsonValidationErrors(['email', 'phone']);
        $this->postJson('/api/password-reset-requests', ['email' => $this->user->email, 'phone' => 'not-a-number'])->assertUnprocessable()->assertJsonValidationErrors('phone');
        $this->assertSame(0, Message::count());
    }

    public function test_public_reset_requests_are_rate_limited(): void
    {
        $payload = ['email' => $this->user->email, 'phone' => '+6281234567890'];
        for ($i = 0; $i < 5; $i++) $this->postJson('/api/password-reset-requests', $payload)->assertCreated();
        $this->postJson('/api/password-reset-requests', $payload)->assertStatus(429);
    }
}
