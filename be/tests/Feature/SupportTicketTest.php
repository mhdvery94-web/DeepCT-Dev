<?php

namespace Tests\Feature;

use App\Models\SupportTicket;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * In-app IT support.
 *
 * The assertions that matter are ownership — a researcher must never reach
 * another account's ticket — and the status flow, because "whose turn is it"
 * drives the badge an administrator works from.
 */
class SupportTicketTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $researcher;
    private User $otherResearcher;

    protected function setUp(): void
    {
        parent::setUp();

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

    private function openTicket(User $user, array $overrides = []): int
    {
        return $this->apiAs($this->tokenAs($user))
            ->postJson('/api/support/tickets', array_merge([
                'subject' => 'Upload keeps failing',
                'category' => 'upload',
                'message' => 'The archive reaches 80% and then stops.',
            ], $overrides))
            ->assertCreated()
            ->json('data.id');
    }

    // ------------------------------------------------------------ raising

    public function test_a_researcher_can_open_a_ticket(): void
    {
        $response = $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/support/tickets', [
                'subject' => 'Upload keeps failing',
                'category' => 'upload',
                'priority' => 'high',
                'message' => 'The archive reaches 80% and then stops.',
            ]);

        $response->assertCreated()
            ->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.priority', 'high')
            ->assertJsonPath('data.awaiting_admin', true)
            ->assertJsonPath('data.message_count', 1);

        $this->assertDatabaseHas('support_tickets', [
            'user_id' => $this->researcher->id,
            'subject' => 'Upload keeps failing',
        ]);
    }

    public function test_a_ticket_needs_a_subject_and_a_message(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/support/tickets', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['subject', 'message']);
    }

    public function test_an_unknown_category_is_rejected(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/support/tickets', [
                'subject' => 'x',
                'message' => 'y',
                'category' => 'not-a-category',
            ])
            ->assertStatus(422);
    }

    public function test_opening_a_ticket_is_recorded_in_the_audit_trail(): void
    {
        $this->openTicket($this->researcher);

        $this->assertDatabaseHas('user_activities', [
            'user_id' => $this->researcher->id,
            'activity_type' => 'support_ticket_opened',
        ]);
    }

    // ---------------------------------------------------------- ownership

    public function test_a_researcher_only_lists_their_own_tickets(): void
    {
        $this->openTicket($this->researcher);
        $this->openTicket($this->otherResearcher);

        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/support/tickets')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_a_researcher_cannot_open_someone_elses_ticket(): void
    {
        $id = $this->openTicket($this->otherResearcher);

        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson("/api/support/tickets/{$id}")
            ->assertNotFound();
    }

    public function test_a_researcher_cannot_reply_to_someone_elses_ticket(): void
    {
        $id = $this->openTicket($this->otherResearcher);

        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson("/api/support/tickets/{$id}/reply", ['body' => 'nosy'])
            ->assertNotFound();
    }

    public function test_a_researcher_cannot_reach_the_admin_queue(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/admin/support/tickets')
            ->assertForbidden();
    }

    /**
     * Linking a job that is not the caller's would let a ticket be used to
     * probe which job ids exist, so the link is silently dropped instead.
     */
    public function test_a_job_belonging_to_someone_else_is_not_linked(): void
    {
        $id = $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/support/tickets', [
                'subject' => 'Probing',
                'message' => 'x',
                'analysis_record_id' => 99999,
            ])
            ->assertCreated()
            ->json('data.id');

        $this->assertNull(SupportTicket::find($id)->analysis_record_id);
    }

    // ----------------------------------------------------- conversation

    public function test_an_admin_sees_every_ticket_with_a_waiting_count(): void
    {
        $this->openTicket($this->researcher);
        $this->openTicket($this->otherResearcher);

        $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/support/tickets')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.open_count', 2)
            ->assertJsonPath('meta.awaiting_admin_count', 2);
    }

    public function test_an_admin_reply_moves_the_ticket_and_clears_the_flag(): void
    {
        $id = $this->openTicket($this->researcher);

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/support/tickets/{$id}/reply", [
                'body' => 'Which frames were in the archive?',
            ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'in_progress')
            ->assertJsonPath('data.awaiting_admin', false)
            ->assertJsonPath('data.message_count', 2);
    }

    public function test_a_researcher_reply_puts_it_back_on_the_admin(): void
    {
        $id = $this->openTicket($this->researcher);

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/support/tickets/{$id}/reply", ['body' => 'Which frames?'])
            ->assertCreated();

        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson("/api/support/tickets/{$id}/reply", ['body' => '001 and 005.'])
            ->assertCreated()
            ->assertJsonPath('data.awaiting_admin', true);
    }

    /**
     * Stamped at write time, so promoting the author later cannot turn old
     * messages into staff replies.
     */
    public function test_replies_record_which_side_wrote_them(): void
    {
        $id = $this->openTicket($this->researcher);

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/support/tickets/{$id}/reply", ['body' => 'Looking into it.'])
            ->assertCreated();

        $messages = $this->apiAs($this->tokenAs($this->researcher))
            ->getJson("/api/support/tickets/{$id}")
            ->assertOk()
            ->json('data.messages');

        $this->assertFalse($messages[0]['from_admin'], 'the opening message is the user');
        $this->assertTrue($messages[1]['from_admin'], 'the reply is staff');
    }

    // ---------------------------------------------------------- lifecycle

    public function test_an_admin_can_resolve_a_ticket(): void
    {
        $id = $this->openTicket($this->researcher);

        $this->apiAs($this->tokenAs($this->admin))
            ->patchJson("/api/admin/support/tickets/{$id}", ['status' => 'resolved'])
            ->assertOk()
            ->assertJsonPath('data.status', 'resolved')
            ->assertJsonPath('data.awaiting_admin', false);

        $ticket = SupportTicket::find($id);
        $this->assertNotNull($ticket->resolved_at);
        $this->assertSame($this->admin->id, $ticket->resolved_by);
    }

    /** A problem that comes back should continue where it left off. */
    public function test_replying_to_a_resolved_ticket_reopens_it(): void
    {
        $id = $this->openTicket($this->researcher);

        $this->apiAs($this->tokenAs($this->admin))
            ->patchJson("/api/admin/support/tickets/{$id}", ['status' => 'resolved'])
            ->assertOk();

        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson("/api/support/tickets/{$id}/reply", ['body' => 'It happened again.'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'in_progress')
            ->assertJsonPath('data.awaiting_admin', true);
    }

    public function test_a_closed_ticket_refuses_replies(): void
    {
        $id = $this->openTicket($this->researcher);

        $this->apiAs($this->tokenAs($this->admin))
            ->patchJson("/api/admin/support/tickets/{$id}", ['status' => 'closed'])
            ->assertOk();

        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson("/api/support/tickets/{$id}/reply", ['body' => 'hello?'])
            ->assertStatus(409);
    }

    public function test_the_admin_queue_can_be_filtered_to_what_needs_a_reply(): void
    {
        $waiting = $this->openTicket($this->researcher);
        $answered = $this->openTicket($this->otherResearcher);

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/support/tickets/{$answered}/reply", ['body' => 'On it.'])
            ->assertCreated();

        $ids = collect(
            $this->apiAs($this->tokenAs($this->admin))
                ->getJson('/api/admin/support/tickets?awaiting=1')
                ->assertOk()
                ->json('data')
        )->pluck('id')->all();

        $this->assertSame([$waiting], $ids);
    }

    public function test_an_admin_can_delete_a_ticket(): void
    {
        $id = $this->openTicket($this->researcher);

        $this->apiAs($this->tokenAs($this->admin))
            ->deleteJson("/api/admin/support/tickets/{$id}")
            ->assertOk();

        $this->assertSame(0, SupportTicket::count());
        $this->assertDatabaseCount('support_ticket_messages', 0);
    }

    // ------------------------------------------------- from the sign-in page

    public function test_someone_locked_out_can_raise_a_ticket_without_signing_in(): void
    {
        $response = $this->postJson('/api/support/tickets/public', [
            'name' => 'Dyanna',
            'email' => 'dyanna@brin.go.id',
            'subject' => 'Password no longer works',
            'category' => 'account',
            'message' => 'Sign-in says invalid credentials since this morning.',
        ]);

        $response->assertCreated();

        $ticket = SupportTicket::firstOrFail();
        $this->assertNull($ticket->user_id);
        $this->assertSame('Dyanna', $ticket->guest_name);
        $this->assertSame('dyanna@brin.go.id', $ticket->guest_email);
        $this->assertTrue($ticket->awaiting_admin);
    }

    public function test_a_public_ticket_needs_a_name_and_a_real_address(): void
    {
        $this->postJson('/api/support/tickets/public', [
            'email' => 'not-an-address',
            'subject' => 'Help',
            'message' => 'Something broke.',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['name', 'email']);
    }

    public function test_a_public_ticket_reaches_the_admin_queue(): void
    {
        $this->postJson('/api/support/tickets/public', [
            'name' => 'Dyanna',
            'email' => 'dyanna@brin.go.id',
            'subject' => 'Password no longer works',
            'message' => 'Sign-in says invalid credentials.',
        ])->assertCreated();

        $response = $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/support/tickets')
            ->assertOk();

        $response->assertJsonPath('data.0.is_guest', true)
            ->assertJsonPath('data.0.guest.email', 'dyanna@brin.go.id')
            ->assertJsonPath('data.0.user', null)
            ->assertJsonPath('meta.awaiting_admin_count', 1);
    }

    public function test_a_public_ticket_is_not_attached_to_a_matching_account(): void
    {
        // The address is unverified, so attaching it to the account that owns
        // it would let anyone plant messages in that researcher's ticket list.
        $this->postJson('/api/support/tickets/public', [
            'name' => 'Impostor',
            'email' => $this->researcher->email,
            'subject' => 'Please reset everything',
            'message' => 'Trust me.',
        ])->assertCreated();

        $this->assertNull(SupportTicket::firstOrFail()->user_id);

        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/support/tickets')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_a_guest_message_is_attributed_to_the_name_given(): void
    {
        $this->postJson('/api/support/tickets/public', [
            'name' => 'Dyanna',
            'email' => 'dyanna@brin.go.id',
            'subject' => 'Password no longer works',
            'message' => 'Sign-in says invalid credentials.',
        ])->assertCreated();

        $id = SupportTicket::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->getJson("/api/support/tickets/{$id}")
            ->assertOk()
            ->assertJsonPath('data.messages.0.author', 'Dyanna')
            ->assertJsonPath('data.messages.0.from_admin', false);
    }
}
