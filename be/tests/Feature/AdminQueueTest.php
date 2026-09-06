<?php

namespace Tests\Feature;

use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Who is using the model, without anybody having to work it out.
 *
 * The administrator's only previous route to this was the activity log, where
 * "started an analysis" has no matching "still going" — so the answer had to
 * be inferred, and two overlapping runs broke the inference. These assertions
 * pin the replacement: live state, read from the records the worker acts on,
 * in the order the worker will reach them.
 */
class AdminQueueTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $alice;
    private User $bob;
    private Model $model;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = $this->makeUser('Admin', 'admin@brin.go.id', 'admin');
        $this->alice = $this->makeUser('Alice', 'alice@brin.go.id');
        $this->bob = $this->makeUser('Bob', 'bob@brin.go.id');

        $this->model = Model::create([
            'name' => 'deepCT',
            'version' => 'v1',
            'kind' => 'inference',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online',
            'is_active' => true,
        ]);
    }

    private function makeUser(string $name, string $email, string $role = 'user'): User
    {
        return User::create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make('password123'),
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function token(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    private function record(User $owner, string $status, int $minutesAgo, int $frames = 10): AnalysisRecord
    {
        $record = AnalysisRecord::create([
            'job_id' => 'job-' . uniqid(),
            'user_id' => $owner->id,
            'model_id' => $this->model->id,
            'file_name' => 'frames.zip',
            'input_files_count' => $frames,
            'status' => $status,
            'expires_at' => now()->addDay(),
        ]);

        // `created_at` decides the order, and Eloquent stamps it on insert.
        $record->forceFill(['created_at' => now()->subMinutes($minutesAgo)])->save();

        return $record->fresh();
    }

    public function test_only_an_administrator_can_read_the_queue(): void
    {
        $this->apiAs($this->token($this->alice))
            ->getJson('/api/admin/queue')
            ->assertForbidden();

        $this->apiAs(null)
            ->getJson('/api/admin/queue')
            ->assertUnauthorized();
    }

    public function test_the_running_job_names_who_it_belongs_to(): void
    {
        $this->record($this->alice, 'processing', 3, frames: 42);

        $response = $this->apiAs($this->token($this->admin))
            ->getJson('/api/admin/queue')
            ->assertOk();

        $response->assertJsonPath('data.busy', 1);
        $response->assertJsonPath('data.running.0.user.name', 'Alice');
        $response->assertJsonPath('data.running.0.user.email', 'alice@brin.go.id');
        $response->assertJsonPath('data.running.0.model.name', 'deepCT');
        $response->assertJsonPath('data.running.0.input_files_count', 42);

        // A running job is not waiting for anything. Numbering it alongside
        // the queue would say it is still in the line.
        $response->assertJsonPath('data.running.0.queue_position', null);
    }

    public function test_waiting_jobs_are_numbered_in_the_order_they_arrived(): void
    {
        $first = $this->record($this->alice, 'pending', 30);
        $second = $this->record($this->bob, 'pending', 20);
        $third = $this->record($this->alice, 'pending', 10);

        $response = $this->apiAs($this->token($this->admin))
            ->getJson('/api/admin/queue')
            ->assertOk();

        $response->assertJsonPath('data.queued', 3);

        $this->assertSame(
            [$first->id, $second->id, $third->id],
            array_column($response->json('data.waiting'), 'id')
        );
        $this->assertSame(
            [1, 2, 3],
            array_column($response->json('data.waiting'), 'queue_position')
        );

        // Two accounts interleaved, which is exactly the case the activity log
        // could not answer.
        $this->assertSame(
            ['Alice', 'Bob', 'Alice'],
            array_column(array_column($response->json('data.waiting'), 'user'), 'name')
        );
    }

    public function test_finished_work_is_not_on_the_board(): void
    {
        $this->record($this->alice, 'completed', 60);
        $this->record($this->bob, 'failed', 50);
        $this->record($this->alice, 'uploaded', 40);

        $response = $this->apiAs($this->token($this->admin))
            ->getJson('/api/admin/queue')
            ->assertOk();

        // Live state, not history. An upload nobody has started is not queued
        // either — it is waiting on its owner, not on the GPU.
        $response->assertJsonPath('data.busy', 0);
        $response->assertJsonPath('data.queued', 0);
    }

    /**
     * The number an administrator reads and the number the researcher reads
     * must be the same number, or one screen contradicts the other.
     */
    public function test_the_administrator_and_the_owner_see_one_ordering(): void
    {
        $this->record($this->alice, 'pending', 30);
        $this->record($this->bob, 'pending', 20);
        $mine = $this->record($this->alice, 'pending', 10);

        $board = $this->apiAs($this->token($this->admin))
            ->getJson('/api/admin/queue')
            ->assertOk()
            ->json('data.waiting');

        $onBoard = collect($board)->firstWhere('id', $mine->id);

        $own = $this->apiAs($this->token($this->alice))
            ->getJson('/api/predictions')
            ->assertOk()
            ->json('data');

        $onOwn = collect($own)->firstWhere('id', $mine->id);

        // Third overall, and third on the owner's screen too — not "second of
        // Alice's two", which is what a per-account count would have said.
        $this->assertSame(3, $onBoard['queue_position']);
        $this->assertSame(3, $onOwn['queue_position']);
        $this->assertSame(
            $onBoard['estimated_wait_minutes'],
            $onOwn['estimated_wait_minutes']
        );
    }

    /**
     * `analysis_records.user_id` cascades, so deleting an account takes its
     * queued work with it — the board cannot show an ownerless row because one
     * cannot exist. `model_id` is `set null` instead, so *that* is the gap a
     * live board can fall into: a model deregistered while its work is still
     * queued, and a board that threw on it would be useless exactly when
     * somebody is trying to understand a mess.
     */
    public function test_a_job_whose_model_was_deregistered_still_lists(): void
    {
        $record = $this->record($this->bob, 'pending', 5);
        $this->model->delete();

        $response = $this->apiAs($this->token($this->admin))
            ->getJson('/api/admin/queue')
            ->assertOk();

        $response->assertJsonPath('data.queued', 1);
        $response->assertJsonPath('data.waiting.0.id', $record->id);
        $response->assertJsonPath('data.waiting.0.model', null);

        // The owner is still the point of the screen, and is still there.
        $response->assertJsonPath('data.waiting.0.user.name', 'Bob');
    }

    public function test_deleting_an_account_clears_its_queued_work(): void
    {
        $this->record($this->alice, 'pending', 30);
        $this->record($this->bob, 'pending', 20);

        $this->bob->delete();

        $this->apiAs($this->token($this->admin))
            ->getJson('/api/admin/queue')
            ->assertOk()
            ->assertJsonPath('data.queued', 1)
            ->assertJsonPath('data.waiting.0.user.name', 'Alice')
            // And the numbering closes up behind it rather than leaving a hole.
            ->assertJsonPath('data.waiting.0.queue_position', 1);
    }

    public function test_the_administrator_is_told_when_nothing_is_consuming_the_queue(): void
    {
        // A long queue and a dead worker look identical from a list of waiting
        // jobs, and they call for opposite responses.
        $this->record($this->alice, 'pending', 30);

        \Illuminate\Support\Facades\DB::table('jobs')->insert([
            'queue' => 'default',
            'payload' => '{}',
            'attempts' => 0,
            'reserved_at' => null,
            'available_at' => time() - 600,
            'created_at' => time() - 600,
        ]);

        $response = $this->apiAs($this->token($this->admin))
            ->getJson('/api/admin/queue')
            ->assertOk();

        $response->assertJsonPath('meta.stalled', true);
        $this->assertStringContainsString(
            'serve:all',
            $response->json('meta.queue_message')
        );
    }

    /**
     * One definition of the queue, or two screens that contradict each other.
     *
     * The board numbers an ordering; `AnalysisController` counted the rows
     * that precede a record. Those agree until two uploads share a timestamp —
     * ordinary, because a chunked upload assembles in well under a second —
     * and then the researcher is told "1" while the administrator is looking
     * at them in second place. 1.31.0 recorded this as settled; it was settled
     * for the list endpoint only.
     */
    public function test_a_researcher_and_the_board_agree_on_a_position(): void
    {
        $at = now()->subMinutes(10);

        $first = $this->record($this->alice, 'pending', 10);
        $second = $this->record($this->bob, 'pending', 10);
        $first->forceFill(['created_at' => $at])->save();
        $second->forceFill(['created_at' => $at])->save();

        $waiting = collect(
            $this->apiAs($this->token($this->admin))
                ->getJson('/api/admin/queue')
                ->assertOk()
                ->json('data.waiting')
        )->pluck('queue_position', 'id');

        $this->assertSame(1, $waiting[$first->id]);
        $this->assertSame(2, $waiting[$second->id]);

        foreach ([$this->alice->id => $first, $this->bob->id => $second] as $ownerId => $record) {
            $owner = $ownerId === $this->alice->id ? $this->alice : $this->bob;

            $this->assertSame(
                $waiting[$record->id],
                $this->apiAs($this->token($owner))
                    ->getJson("/api/predictions/{$record->id}")
                    ->assertOk()
                    ->json('data.queue_position'),
                "record {$record->id} is in a different place on each screen",
            );
        }
    }
}
