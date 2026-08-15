<?php

namespace Tests\Feature;

use App\Models\AccessRequest;
use App\Models\AnalysisRecord;
use App\Models\Conversation;
use App\Models\Model;
use App\Models\User;
use App\Services\Notifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * In-app notifications.
 *
 * Two things are worth testing and one is not. Worth testing: **who** each
 * event reaches — telling every researcher that a model went offline, or
 * telling nobody that their job finished, are the failures that matter — and
 * that nobody can read or clear somebody else's. Not worth testing: the exact
 * wording, which would only pin the copy in place.
 */
class NotificationTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $secondAdmin;
    private User $researcher;
    private User $otherResearcher;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = $this->makeUser('admin', 'admin@brin.go.id', 'admin');
        $this->secondAdmin = $this->makeUser('admin2', 'admin2@brin.go.id', 'admin');
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

    private function unread(User $user): int
    {
        return $user->fresh()->unreadNotifications()->count();
    }

    /** The `type` of every notification a user holds. */
    private function types(User $user): array
    {
        return $user->fresh()->notifications
            ->map(fn($n) => $n->data['type'])
            ->all();
    }

    // -------------------------------------------------------------- routing

    public function test_a_message_reaches_every_admin_and_no_researcher(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/messages', ['body' => 'The upload stops at 80%.'])
            ->assertCreated();

        $this->assertSame(['message.received'], $this->types($this->admin));
        $this->assertSame(['message.received'], $this->types($this->secondAdmin));

        // The sender does not need telling what they just did.
        $this->assertSame(0, $this->unread($this->researcher));
        $this->assertSame(0, $this->unread($this->otherResearcher));
    }

    public function test_a_reply_reaches_the_researcher_who_asked(): void
    {
        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/messages', ['body' => 'Anyone there?'])
            ->assertCreated();

        $id = Conversation::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/admin/conversations/{$id}/reply", ['body' => 'Here.'])
            ->assertCreated();

        $this->assertSame(['message.reply'], $this->types($this->researcher));
        $this->assertSame(0, $this->unread($this->otherResearcher));
    }

    public function test_a_message_from_the_sign_in_page_reaches_the_admins(): void
    {
        $this->postJson('/api/messages/public', [
            'name' => 'Dyanna',
            'email' => 'dyanna@brin.go.id',
            'body' => 'Cannot sign in.',
        ])->assertCreated();

        $this->assertSame(['message.guest'], $this->types($this->admin));

        // The administrator has to answer this one by email, so the address is
        // in the notification itself rather than one screen away.
        $body = $this->admin->fresh()->notifications->first()->data['body'];
        $this->assertStringContainsString('dyanna@brin.go.id', $body);
    }

    public function test_an_access_request_reaches_the_admins(): void
    {
        $this->postJson('/api/access-requests', [
            'first_name' => 'Dyanna',
            'last_name' => 'Basia',
            'email' => 'dyanna@brin.go.id',
            'institution' => 'BRIN',
        ])->assertCreated();

        $this->assertSame(['access_request.submitted'], $this->types($this->admin));
        $this->assertSame(['access_request.submitted'], $this->types($this->secondAdmin));
    }

    public function test_approving_a_request_welcomes_the_new_account(): void
    {
        $this->postJson('/api/access-requests', [
            'first_name' => 'Dyanna',
            'last_name' => 'Basia',
            'email' => 'dyanna@brin.go.id',
            'institution' => 'BRIN',
        ])->assertCreated();

        $requestId = AccessRequest::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/admin/access-requests/{$requestId}/approve")
            ->assertOk();

        $created = User::where('email', 'dyanna@brin.go.id')->firstOrFail();

        // They cannot read it until they sign in, which is exactly when it is
        // worth having.
        $this->assertSame(['account.approved'], $this->types($created));
    }

    public function test_a_model_going_offline_reaches_the_admins_once(): void
    {
        Http::fake(['worker.example/*' => Http::response('gone', 503)]);

        $model = Model::create([
            'name' => 'deepCT',
            'version' => '1.0',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online',
            'is_active' => true,
        ]);

        $checker = app(\App\Services\ModelHealthChecker::class);

        $checker->check($model->fresh());
        $checker->check($model->fresh());
        $checker->check($model->fresh());

        // Three checks, one notification: the scheduler runs this every five
        // minutes, and an overnight outage must not produce 288 of them.
        $this->assertSame(['model.offline'], $this->types($this->admin));
        $this->assertSame(0, $this->unread($this->researcher));
    }

    public function test_a_model_coming_back_is_announced(): void
    {
        // A sequence, not two calls to Http::fake(): the second call *merges*
        // its stub in and the first one still matches, so the model would
        // never appear to recover.
        Http::fake([
            'worker.example/*' => Http::sequence()
                ->push('gone', 503)
                ->push('', 404),   // 404 from the app itself means it is alive
        ]);

        $model = Model::create([
            'name' => 'deepCT',
            'version' => '1.0',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online',
            'is_active' => true,
        ]);

        $checker = app(\App\Services\ModelHealthChecker::class);
        $checker->check($model->fresh());
        $checker->check($model->fresh());

        // Canonicalising, not asserting an order: both rows are written in the
        // same second, so `created_at desc` ties and the order is decided by
        // insertion — not something worth pinning a test to.
        $this->assertEqualsCanonicalizing(
            ['model.offline', 'model.online'],
            $this->types($this->admin),
        );
    }

    public function test_expiring_results_warn_their_owner_exactly_once(): void
    {
        $record = AnalysisRecord::create([
            'job_id' => 'job-expiring',
            'user_id' => $this->researcher->id,
            'file_name' => 'frames.zip',
            'status' => 'completed',
            'expires_at' => now()->addHours(2),
        ]);

        $this->artisan('predictions:cleanup')->assertSuccessful();
        $this->artisan('predictions:cleanup')->assertSuccessful();

        $this->assertSame(['prediction.expiring'], $this->types($this->researcher));
        $this->assertNotNull($record->fresh()->expiry_notified_at);
    }

    public function test_results_with_hours_left_are_not_warned_about_yet(): void
    {
        AnalysisRecord::create([
            'job_id' => 'job-fresh',
            'user_id' => $this->researcher->id,
            'file_name' => 'frames.zip',
            'status' => 'completed',
            'expires_at' => now()->addHours(20),
        ]);

        $this->artisan('predictions:cleanup')->assertSuccessful();

        $this->assertSame(0, $this->unread($this->researcher));
    }

    // ------------------------------------------------------------- endpoints

    public function test_the_list_is_scoped_to_the_caller(): void
    {
        Notifier::predictionFailed(
            AnalysisRecord::create([
                'job_id' => 'job-1',
                'user_id' => $this->researcher->id,
                'file_name' => 'frames.zip',
                'status' => 'failed',
            ]),
            'The model rejected frame 4.',
        );

        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/notifications')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.type', 'prediction.failed')
            ->assertJsonPath('meta.unread', 1);

        $this->apiAs($this->tokenAs($this->otherResearcher))
            ->getJson('/api/notifications')
            ->assertOk()
            ->assertJsonCount(0, 'data')
            ->assertJsonPath('meta.unread', 0);
    }

    public function test_the_unread_count_carries_the_message_count_too(): void
    {
        // One request feeds both the bell and the Messages badge; the client
        // polls this every 45 seconds and should not need two calls.
        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/messages', ['body' => 'Hello?'])
            ->assertCreated();

        $id = Conversation::firstOrFail()->id;

        $this->apiAs($this->tokenAs($this->admin))
            ->postJson("/api/admin/conversations/{$id}/reply", ['body' => 'Hi.'])
            ->assertCreated();

        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/notifications/unread-count')
            ->assertOk()
            ->assertJsonPath('data.notifications', 1)
            ->assertJsonPath('data.messages', 1);

        // For an administrator the same field counts threads waiting on them.
        $this->apiAs($this->tokenAs($this->admin))
            ->getJson('/api/notifications/unread-count')
            ->assertOk()
            ->assertJsonPath('data.messages', 0);
    }

    public function test_one_notification_can_be_marked_read(): void
    {
        Notifier::accountApproved($this->researcher);

        $id = $this->researcher->fresh()->notifications->first()->id;

        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson("/api/notifications/{$id}/read")
            ->assertOk()
            ->assertJsonPath('data.read', true);

        $this->assertSame(0, $this->unread($this->researcher));
    }

    public function test_everything_can_be_marked_read_at_once(): void
    {
        Notifier::accountApproved($this->researcher);
        Notifier::accountApproved($this->researcher);

        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson('/api/notifications/read-all')
            ->assertOk()
            ->assertJsonPath('data.marked', 2);

        $this->assertSame(0, $this->unread($this->researcher));
    }

    public function test_the_unread_filter_hides_what_has_been_read(): void
    {
        Notifier::accountApproved($this->researcher);
        Notifier::accountApproved($this->researcher);

        $id = $this->researcher->fresh()->notifications->first()->id;

        $this->apiAs($this->tokenAs($this->researcher))
            ->postJson("/api/notifications/{$id}/read")
            ->assertOk();

        $this->apiAs($this->tokenAs($this->researcher))
            ->getJson('/api/notifications?unread=1')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_nobody_can_touch_another_accounts_notification(): void
    {
        Notifier::accountApproved($this->researcher);

        $id = $this->researcher->fresh()->notifications->first()->id;

        // 404 rather than 403: the relation is the authorisation, so as far as
        // this account is concerned the row does not exist.
        $this->apiAs($this->tokenAs($this->otherResearcher))
            ->postJson("/api/notifications/{$id}/read")
            ->assertNotFound();

        $this->apiAs($this->tokenAs($this->otherResearcher))
            ->deleteJson("/api/notifications/{$id}")
            ->assertNotFound();

        $this->assertSame(1, $this->unread($this->researcher));
    }

    public function test_a_notification_can_be_dismissed(): void
    {
        Notifier::accountApproved($this->researcher);

        $id = $this->researcher->fresh()->notifications->first()->id;

        $this->apiAs($this->tokenAs($this->researcher))
            ->deleteJson("/api/notifications/{$id}")
            ->assertOk();

        $this->assertSame(0, $this->researcher->fresh()->notifications()->count());
    }

    public function test_the_list_can_be_cleared(): void
    {
        Notifier::accountApproved($this->researcher);
        Notifier::accountApproved($this->researcher);

        $this->apiAs($this->tokenAs($this->researcher))
            ->deleteJson('/api/notifications')
            ->assertOk()
            ->assertJsonPath('data.deleted', 2);

        $this->assertSame(0, $this->researcher->fresh()->notifications()->count());
    }

    public function test_notifications_need_a_token(): void
    {
        $this->apiAs(null)
            ->getJson('/api/notifications')
            ->assertUnauthorized();
    }

    public function test_deleting_an_account_takes_its_notifications_with_it(): void
    {
        // The notifications table is polymorphic and carries no foreign key,
        // so without an explicit hook these rows would outlive the account
        // that could read them, forever.
        Notifier::accountApproved($this->researcher);
        $this->assertSame(1, DB::table('notifications')->count());

        $this->researcher->delete();

        $this->assertSame(0, DB::table('notifications')
            ->where('notifiable_id', $this->researcher->id)
            ->count());
    }

    public function test_deleting_an_account_revokes_its_tokens(): void
    {
        // Same reason, and worse: `personal_access_tokens` is polymorphic too,
        // so a deleted account would leave live-looking credentials behind.
        $token = $this->tokenAs($this->researcher);
        $this->assertSame(1, DB::table('personal_access_tokens')->count());

        $this->researcher->delete();

        $this->assertSame(0, DB::table('personal_access_tokens')->count());

        $this->apiAs($token)->getJson('/api/user')->assertUnauthorized();
    }
}
