<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * IT support, as messaging.
 *
 * What matters here is that a researcher has exactly **one** thread and no way
 * to name anyone else's, that unread state is tracked in both directions, and
 * that someone locked out can still get a message through.
 */
class MessagingTest extends TestCase
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

    private function makeUser(string $name, string $email, string $role): User
    {
        return User::create([
            'name' => ucfirst($name),
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

    private function send(User $user, string $body): void
    {
        $this->apiAs($this->tokenAs($user))
            ->postJson('/api/messages', ['body' => $body])
            ->assertCreated();
    }

    // ------------------------------------------------------------- writing

    public function test_a_researcher_can_write_to_support(): void
    {
        $response = $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/messages', ['body' => 'The upload stops at 80%.']);

        $response->assertCreated()
            ->assertJsonPath('data.body', 'The upload stops at 80%.')
            ->assertJsonPath('data.from_admin', false);

        $conversation = Conversation::firstOrFail();
        $this->assertSame($this->researcher->id, $conversation->user_id);
        $this->assertSame(1, $conversation->messages()->count());
    }

    public function test_writing_twice_keeps_one_thread(): void
    {
        // The whole point of dropping tickets: a second problem is not a second
        // case to track, it is the next line in the same conversation.
        $this->send($this->researcher, 'The upload stops at 80%.');
        $this->send($this->researcher, 'It happens on Chrome too.');

        $this->assertSame(1, Conversation::count());
        $this->assertSame(2, Message::count());
    }

    public function test_an_empty_message_is_refused(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/messages', ['body' => ''])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['body']);
    }

    public function test_someone_who_never_wrote_gets_an_empty_thread(): void
    {
        // No row is created for silence, or the administrator's inbox would
        // fill up with people who never said anything.
        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/messages')
            ->assertOk()
            ->assertJsonPath('data.id', null)
            ->assertJsonCount(0, 'data.messages');

        $this->assertSame(0, Conversation::count());
    }

    public function test_a_researcher_only_ever_sees_their_own_thread(): void
    {
        $this->send($this->researcher, 'Mine.');
        $this->send($this->otherResearcher, 'Also mine.');

        $bodies = $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/messages')
            ->assertOk()
            ->json('data.messages.*.body');

        $this->assertSame(['Mine.'], $bodies);
    }

    // --------------------------------------------------------------- replies

    public function test_an_admin_can_reply_and_the_researcher_sees_it(): void
    {
        $this->send($this->researcher, 'The upload stops at 80%.');
        $id = Conversation::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/admin/conversations/{$id}/reply", [
                'body' => 'Which browser, and how large is the archive?',
            ])
            ->assertCreated()
            ->assertJsonPath('data.from_admin', true);

        $messages = $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/messages')
            ->assertOk()
            ->json('data.messages');

        $this->assertCount(2, $messages);
        $this->assertTrue($messages[1]['from_admin']);
        $this->assertSame('Admin', $messages[1]['author']);
    }

    public function test_replying_marks_the_researchers_messages_read(): void
    {
        // Answering *is* reading; nothing in a thread is still waiting on the
        // administrator once they have replied to it.
        $this->send($this->researcher, 'Anyone there?');
        $id = Conversation::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/admin/conversations/{$id}/reply", ['body' => 'Here.'])
            ->assertCreated();

        $this->assertSame(0, Conversation::firstOrFail()->unreadForAdmin());
    }

    public function test_a_new_message_pulls_the_thread_out_of_the_archive(): void
    {
        $this->send($this->researcher, 'First problem.');
        $id = Conversation::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->patchJson("/api/admin/conversations/{$id}", ['is_archived' => true])
            ->assertOk();

        $this->send($this->researcher, 'Second problem.');

        // The administrator filed away a conversation, not a person.
        $this->assertFalse(Conversation::firstOrFail()->is_archived);
    }

    // ---------------------------------------------------------------- unread

    public function test_unread_counts_move_in_both_directions(): void
    {
        $this->send($this->researcher, 'Hello?');
        $conversation = Conversation::firstOrFail();

        $this->assertSame(1, $conversation->unreadForAdmin());
        $this->assertSame(0, $conversation->unreadForUser());

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/admin/conversations/{$conversation->id}/reply", [
                'body' => 'Hello.',
            ])->assertCreated();

        $conversation->refresh();
        $this->assertSame(0, $conversation->unreadForAdmin());
        $this->assertSame(1, $conversation->unreadForUser());

        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/messages/read')
            ->assertOk();

        $this->assertSame(0, $conversation->fresh()->unreadForUser());
    }

    public function test_the_admin_inbox_reports_what_is_waiting(): void
    {
        $this->send($this->researcher, 'One.');
        $this->send($this->otherResearcher, 'Two.');

        $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/conversations')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.unread_conversations', 2)
            ->assertJsonPath('meta.unread_messages', 2);
    }

    public function test_the_inbox_can_be_filtered_to_unread(): void
    {
        $this->send($this->researcher, 'Unread.');
        $this->send($this->otherResearcher, 'Will be read.');

        $read = Conversation::where('user_id', $this->otherResearcher->id)->firstOrFail();

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/admin/conversations/{$read->id}/read")
            ->assertOk();

        $names = $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/conversations?unread=1')
            ->assertOk()
            ->json('data.*.name');

        $this->assertSame(['Researcher'], $names);
    }

    public function test_an_archived_thread_leaves_the_inbox_without_being_deleted(): void
    {
        $this->send($this->researcher, 'Sorted now, thanks.');
        $id = Conversation::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->patchJson("/api/admin/conversations/{$id}", ['is_archived' => true])
            ->assertOk();

        $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/conversations')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/conversations?archived=1')
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->assertSame(1, Conversation::count());
    }

    // ------------------------------------------------------ from the sign-in page

    public function test_someone_locked_out_can_still_write(): void
    {
        $this->postJson('/api/messages/public', [
            'name' => 'Dyanna',
            'email' => 'dyanna@brin.go.id',
            'body' => 'Sign-in says invalid credentials since this morning.',
        ])->assertCreated();

        $conversation = Conversation::firstOrFail();
        $this->assertNull($conversation->user_id);
        $this->assertSame('Dyanna', $conversation->guest_name);
        $this->assertSame('dyanna@brin.go.id', $conversation->guest_email);
    }

    public function test_a_public_message_needs_a_name_and_a_real_address(): void
    {
        $this->postJson('/api/messages/public', [
            'email' => 'not-an-address',
            'body' => 'Help.',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['name', 'email']);
    }

    public function test_a_guest_thread_is_not_attached_to_a_matching_account(): void
    {
        // The address is unverified at write time, so attaching it there
        // would let anyone plant messages in that researcher's thread just by
        // typing their address. (Signing in with that address later is a
        // different, deliberate story — see the adoption-on-login tests: only
        // someone who can pass the account's own password gets treated as
        // its owner.)
        $this->postJson('/api/messages/public', [
            'name' => 'Impostor',
            'email' => $this->researcher->email,
            'body' => 'Please reset everything.',
        ])->assertCreated();

        $this->assertNull(Conversation::firstOrFail()->user_id);
    }

    public function test_a_guest_thread_is_flagged_in_the_inbox(): void
    {
        $this->postJson('/api/messages/public', [
            'name' => 'Dyanna',
            'email' => 'dyanna@brin.go.id',
            'body' => 'Cannot sign in.',
        ])->assertCreated();

        $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/admin/conversations')
            ->assertOk()
            ->assertJsonPath('data.0.is_guest', true)
            ->assertJsonPath('data.0.name', 'Dyanna')
            ->assertJsonPath('data.0.guest_email', 'dyanna@brin.go.id')
            ->assertJsonPath('data.0.user', null);
    }

    public function test_a_guest_message_is_attributed_to_the_name_given(): void
    {
        $this->postJson('/api/messages/public', [
            'name' => 'Dyanna',
            'email' => 'dyanna@brin.go.id',
            'body' => 'Cannot sign in.',
        ])->assertCreated();

        $id = Conversation::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->getJson("/api/admin/conversations/{$id}")
            ->assertOk()
            ->assertJsonPath('data.messages.0.author', 'Dyanna');
    }

    // ------------------------------------------------------ rate limiting

    public function test_the_public_message_route_allows_five_then_throttles(): void
    {
        $write = fn () => $this->postJson('/api/messages/public', [
            'name' => 'Dyanna',
            'email' => 'dyanna@brin.go.id',
            'body' => 'Cannot sign in.',
        ]);

        for ($i = 0; $i < 5; $i++) {
            $write()->assertCreated();
        }

        // The 6th request within the window is throttled...
        $sixth = $write();
        $sixth->assertStatus(429);

        // ...and the window is 10 minutes (600s), not the old 60-minute one.
        // A stale `throttle:5,60` would report a Retry-After close to 3600.
        $retryAfter = (int) $sixth->headers->get('Retry-After');
        $this->assertGreaterThan(0, $retryAfter);
        $this->assertLessThanOrEqual(600, $retryAfter);
    }

    // ------------------------------------------------- adoption on login

    public function test_a_guest_thread_is_merged_into_the_account_on_login(): void
    {
        $this->postJson('/api/messages/public', [
            'name' => 'Researcher',
            'email' => $this->researcher->email,
            'body' => 'Locked out yesterday.',
        ])->assertCreated();

        $guestConversationId = Conversation::firstOrFail()->id;

        // Signing in is what proves the address belongs to them.
        $this->tokenAs($this->researcher);

        $this->assertSame(1, Conversation::count());

        $conversation = Conversation::firstOrFail();
        $this->assertSame($this->researcher->id, $conversation->user_id);
        $this->assertFalse($conversation->is_archived);
        $this->assertNotNull($conversation->last_message_at);

        $this->assertSame(1, $conversation->messages()->count());
        $this->assertSame('Locked out yesterday.', $conversation->messages()->first()->body);

        // The guest row itself is gone, not just detached.
        $this->assertDatabaseMissing('conversations', ['id' => $guestConversationId]);
    }

    public function test_login_with_no_matching_guest_thread_changes_nothing(): void
    {
        $this->tokenAs($this->researcher);

        $this->assertSame(0, Conversation::count());
    }

    public function test_login_appends_a_guest_thread_to_an_existing_conversation(): void
    {
        $this->send($this->researcher, 'My own message, written signed in.');
        $ownId = Conversation::firstOrFail()->id;

        $this->postJson('/api/messages/public', [
            'name' => 'Researcher',
            'email' => $this->researcher->email,
            'body' => 'Also could not sign in once.',
        ])->assertCreated();

        // Two threads exist right up until login merges them.
        $this->assertSame(2, Conversation::count());

        $this->apiAs($this->tokenAs($this->admin))
            ->patchJson("/api/admin/conversations/{$ownId}", ['is_archived' => true])
            ->assertOk();

        $this->tokenAs($this->researcher);

        // Merged into the one the researcher already had — no duplicate.
        $this->assertSame(1, Conversation::count());

        $conversation = Conversation::findOrFail($ownId);
        $this->assertSame(2, $conversation->messages()->count());
        $this->assertSame(
            ['My own message, written signed in.', 'Also could not sign in once.'],
            $conversation->messages()->pluck('body')->all(),
        );

        // Signing in also pulls the merged thread back out of the archive.
        $this->assertFalse($conversation->is_archived);
    }

    // ----------------------------------------------------------- permissions

    public function test_a_researcher_cannot_reach_the_inbox(): void
    {
        $this->send($this->researcher, 'Mine.');
        $id = Conversation::firstOrFail()->id;
        $token = $this->tokenAs($this->researcher);

        $this->apiAs($token)->getJson('/api/admin/conversations')->assertForbidden();
        $this->apiAs($token)->getJson("/api/admin/conversations/{$id}")->assertForbidden();
        $this->apiAs($token)
            ->postJson("/api/admin/conversations/{$id}/reply", ['body' => 'hi'])
            ->assertForbidden();
        $this->apiAs($token)
            ->deleteJson("/api/admin/conversations/{$id}")
            ->assertForbidden();
    }

    public function test_writing_requires_a_token(): void
    {
        $this->apiAs(null)
            ->postJson('/api/messages', ['body' => 'anyone?'])
            ->assertUnauthorized();
    }

    public function test_an_admin_can_delete_a_thread(): void
    {
        $this->send($this->researcher, 'Never mind.');
        $id = Conversation::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->deleteJson("/api/admin/conversations/{$id}")
            ->assertOk();

        $this->assertSame(0, Conversation::count());
        $this->assertSame(0, Message::count());
    }

    public function test_deleting_an_account_takes_its_thread_with_it(): void
    {
        $this->send($this->researcher, 'Hello.');

        $this->researcher->delete();

        $this->assertSame(0, Conversation::count());
        $this->assertSame(0, Message::count());
    }

    public function test_sending_a_message_is_recorded_in_the_audit_trail(): void
    {
        $this->send($this->researcher, 'The upload stops at 80%.');

        $this->assertDatabaseHas('user_activities', [
            'user_id' => $this->researcher->id,
            'activity_type' => 'support_message_sent',
        ]);
    }
}
