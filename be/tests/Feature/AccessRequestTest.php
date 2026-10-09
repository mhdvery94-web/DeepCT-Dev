<?php

namespace Tests\Feature;

use App\Models\AccessRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * The "Join Research" queue.
 *
 * Submission is the only unauthenticated write path besides login, so the
 * guards around it matter: duplicates, existing accounts, and the fact that
 * approving must actually create a working account rather than just flipping
 * a status column.
 */
class AccessRequestTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $researcher;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::create([
            'name' => 'Admin', 'email' => 'admin@brin.go.id',
            'password' => Hash::make('password123'), 'role' => 'admin', 'is_active' => true,
        ]);

        $this->researcher = User::create([
            'name' => 'Researcher',
            'email' => 'researcher@brin.go.id', 'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);
    }

    private function payload(array $overrides = []): array
    {
        return array_merge([
            'first_name' => 'Siti',
            'last_name' => 'Rahayu',
            'email' => 'siti.rahayu@brin.go.id',
            'institution' => 'BRIN — Pusat Riset Fisika',
            'reason' => 'Neutron CT analysis for material research.',
        ], $overrides);
    }

    // ---------------------------------------------------------- submission

    public function test_requested_phone_is_preserved_on_the_approved_account(): void
    {
        $id = $this->postJson('/api/access-requests', $this->payload(['phone' => '+6281234567890']))
            ->assertCreated()->json('data.id');
        $token = $this->admin->createToken('test')->plainTextToken;
        $this->apiAs($token)->postJson("/api/admin/access-requests/{$id}/approve")
            ->assertOk();
        $this->assertDatabaseHas('access_requests', ['id' => $id, 'phone' => '+6281234567890']);
        $this->assertDatabaseHas('users', ['email' => 'siti.rahayu@brin.go.id', 'phone' => '+6281234567890']);
    }

    public function test_invalid_requested_phone_is_rejected(): void
    {
        $this->postJson('/api/access-requests', $this->payload(['phone' => 'invalid']))
            ->assertUnprocessable()->assertJsonValidationErrors('phone');
        $this->assertSame(0, AccessRequest::count());
    }

    public function test_anyone_can_submit_a_request(): void
    {
        $response = $this->postJson('/api/access-requests', $this->payload());

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'pending');

        $this->assertDatabaseHas('access_requests', [
            'email' => 'siti.rahayu@brin.go.id',
            'status' => 'pending',
        ]);
    }

    public function test_submission_requires_the_essential_fields(): void
    {
        $this->postJson('/api/access-requests', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['first_name', 'last_name', 'email', 'institution']);
    }

    public function test_a_malformed_email_is_rejected(): void
    {
        $this->postJson('/api/access-requests', $this->payload(['email' => 'not-an-email']))
            ->assertStatus(422)
            ->assertJsonValidationErrors('email');
    }

    /** Someone who already has an account should sign in, not apply. */
    public function test_an_existing_account_is_told_to_sign_in(): void
    {
        $response = $this->postJson('/api/access-requests', $this->payload([
            'email' => 'researcher@brin.go.id',
        ]));

        $response->assertStatus(409);
        $this->assertStringContainsString('already exists', $response->json('message'));
        $this->assertSame(0, AccessRequest::count());
    }

    public function test_a_duplicate_pending_request_is_refused(): void
    {
        $this->postJson('/api/access-requests', $this->payload())->assertCreated();

        $this->postJson('/api/access-requests', $this->payload())
            ->assertStatus(409);

        $this->assertSame(1, AccessRequest::count());
    }

    /** A rejected applicant must have a way back in. */
    public function test_reapplying_after_a_rejection_is_allowed(): void
    {
        $this->postJson('/api/access-requests', $this->payload())->assertCreated();

        AccessRequest::first()->update([
            'status' => 'rejected',
            'reviewed_by' => $this->admin->id,
            'reviewed_at' => now(),
        ]);

        $this->postJson('/api/access-requests', $this->payload())->assertCreated();

        $this->assertSame(2, AccessRequest::count());
    }

    // ------------------------------------------------------------- review

    public function test_a_researcher_cannot_see_the_queue(): void
    {
        $token = $this->tokenFor('researcher@brin.go.id', 'password123');

        $this->apiAs($token)->getJson('/api/admin/access-requests')->assertForbidden();
    }

    public function test_an_admin_sees_the_queue_with_a_pending_count(): void
    {
        $this->postJson('/api/access-requests', $this->payload())->assertCreated();

        $token = $this->tokenFor('admin@brin.go.id', 'password123');

        $this->apiAs($token)->getJson('/api/admin/access-requests')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.pending_count', 1);
    }

    /**
     * The behaviour the whole feature turns on: approving creates a usable
     * account, not merely a status change.
     */
    public function test_approving_creates_an_account_that_can_sign_in(): void
    {
        $this->postJson('/api/access-requests', $this->payload())->assertCreated();
        $request = AccessRequest::first();

        $token = $this->tokenFor('admin@brin.go.id', 'password123');

        $response = $this->apiAs($token)
            ->postJson("/api/admin/access-requests/{$request->id}/approve")
            ->assertOk();

        $password = $response->json('data.default_password');
        $email = $response->json('data.user.email');

        $this->assertSame('siti.rahayu@brin.go.id', $email);
        $this->assertSame('Siti Rahayu', $response->json('data.user.name'));

        $request->refresh();
        $this->assertSame('approved', $request->status);
        $this->assertSame($this->admin->id, $request->reviewed_by);
        $this->assertNotNull($request->created_user_id);

        // The account genuinely works — and is told to replace the password it
        // was handed, since that one is the same for everyone.
        $this->apiAs(null)->postJson('/api/login', [
            'email' => $email,
            'password' => $password,
        ])
            ->assertOk()
            ->assertJsonPath('data.user.must_change_password', true);
    }

    public function test_approving_twice_is_refused(): void
    {
        $this->postJson('/api/access-requests', $this->payload())->assertCreated();
        $token = $this->tokenFor('admin@brin.go.id', 'password123');

        $id = AccessRequest::first()->id;
        $this->apiAs($token)->postJson("/api/admin/access-requests/{$id}/approve")->assertOk();

        $this->apiAs($token)
            ->postJson("/api/admin/access-requests/{$id}/approve")
            ->assertStatus(409);

        $this->assertSame(3, User::count(), 'no second account was created');
    }

    public function test_rejecting_records_the_reason(): void
    {
        $this->postJson('/api/access-requests', $this->payload())->assertCreated();
        $token = $this->tokenFor('admin@brin.go.id', 'password123');

        $id = AccessRequest::first()->id;
        $this->apiAs($token)
            ->postJson("/api/admin/access-requests/{$id}/reject", [
                'note' => 'Not affiliated with BRIN.',
            ])
            ->assertOk();

        $request = AccessRequest::first();
        $this->assertSame('rejected', $request->status);
        $this->assertSame('Not affiliated with BRIN.', $request->review_note);
        $this->assertSame(2, User::count(), 'rejection creates no account');
    }

    public function test_the_queue_can_be_filtered_by_status(): void
    {
        $this->postJson('/api/access-requests', $this->payload())->assertCreated();
        $this->postJson('/api/access-requests', $this->payload([
            'email' => 'budi@brin.go.id',
        ]))->assertCreated();

        $token = $this->tokenFor('admin@brin.go.id', 'password123');
        $firstId = AccessRequest::where('email', 'siti.rahayu@brin.go.id')->value('id');
        $this->apiAs($token)->postJson("/api/admin/access-requests/{$firstId}/reject")->assertOk();

        $this->apiAs($token)
            ->getJson('/api/admin/access-requests?status=pending')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.email', 'budi@brin.go.id');
    }

    public function test_review_actions_are_recorded_in_the_audit_trail(): void
    {
        $this->postJson('/api/access-requests', $this->payload())->assertCreated();
        $token = $this->tokenFor('admin@brin.go.id', 'password123');

        $id = AccessRequest::first()->id;
        $this->apiAs($token)->postJson("/api/admin/access-requests/{$id}/approve")->assertOk();

        $this->assertDatabaseHas('user_activities', [
            'user_id' => $this->admin->id,
            'activity_type' => 'access_request_approved',
        ]);
    }
}
