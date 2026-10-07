<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * The training queue has to be able to move.
 *
 * A run was dispatched once, at creation, and never again — so an attempt that
 * failed left the job at `queued` for ever. Six accumulated in one afternoon.
 * Worse, once the screen started showing a queue position, that number was a
 * promise nothing could keep: a line that cannot advance.
 */
class DispatchQueuedTrainingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'training.worker_token' => 'test-worker-token-0123456789',
            'training.callback_url' => 'https://platform.example',
        ]);
    }

    private function trainer(): Model
    {
        return Model::create([
            'name' => 'Remote trainer',
            'version' => 'v1',
            'kind' => 'trainer',
            'endpoint_url' => 'https://trainer.example/train',
            'status' => 'online',
            'is_active' => true,
        ]);
    }

    private function job(string $status, string $createdAt): TrainingJob
    {
        $owner = User::firstOrCreate(
            ['email' => 'researcher@brin.go.id'],
            [
                'name' => 'Researcher',
                'password' => Hash::make('password123'),
                'role' => 'user',
                'is_active' => true,
            ],
        );

        $dataset = TrainingDataset::create([
            'name' => 'Frames',
            'source_type' => 'url',
            'source_url' => 'https://example.org/dataset.zip',
            'uploaded_by' => $owner->id,
        ]);

        return TrainingJob::create([
            'name' => "Run {$createdAt}",
            'training_dataset_id' => $dataset->id,
            'total_epochs' => 5,
            'status' => $status,
            'created_by' => $owner->id,
            'created_at' => $createdAt,
        ]);
    }

    public function test_the_oldest_waiting_run_goes_first(): void
    {
        Http::fake(['*' => Http::response(['accepted' => true], 200)]);
        $this->trainer();

        $older = $this->job('queued', '2026-08-25 09:00:00');
        $newer = $this->job('queued', '2026-08-25 10:00:00');

        $this->artisan('training:dispatch-queued')->assertSuccessful();

        // Same ordering the researcher is shown as their position. Two
        // definitions of "next" would surface as a queue that jumps.
        $this->assertNotNull($older->fresh()->dispatched_at);
        $this->assertNull($newer->fresh()->dispatched_at);
    }

    public function test_nothing_is_sent_while_a_run_is_in_progress(): void
    {
        Http::fake(['*' => Http::response(['accepted' => true], 200)]);
        $this->trainer();

        $this->job('running', '2026-08-25 09:00:00');
        $waiting = $this->job('queued', '2026-08-25 10:00:00');

        $this->artisan('training:dispatch-queued')->assertSuccessful();

        // One GPU. A second job would only collect a refusal.
        $this->assertNull($waiting->fresh()->dispatched_at);
        Http::assertNothingSent();
    }

    public function test_an_empty_queue_is_not_an_error(): void
    {
        $this->trainer();

        $this->artisan('training:dispatch-queued')->assertSuccessful();
    }

    public function test_a_run_that_cannot_be_sent_says_why_on_its_own_row(): void
    {
        Http::fake(['*' => Http::response(['detail' => 'nope'], 500)]);
        $this->trainer();

        $job = $this->job('queued', '2026-08-25 09:00:00');

        // Not a command failure: a trainer that is down is an ordinary state,
        // and a non-zero exit would fill the scheduler's log with alarms about
        // something nobody can fix from this side.
        $this->artisan('training:dispatch-queued')->assertSuccessful();

        $fresh = $job->fresh();
        $this->assertSame('queued', $fresh->status);
        $this->assertNotNull($fresh->error_message);
    }

    public function test_a_failed_run_is_retried_on_the_next_tick(): void
    {
        // The behaviour the whole command exists for: one bad attempt must not
        // strand a run for ever.
        //
        // A sequence rather than two `fake()` calls — the second call *appends*
        // a stub, so a `*` pattern registered first keeps matching and the
        // "recovery" never happens. Caught by this test failing.
        Http::fake([
            '*' => Http::sequence()
                ->push([], 500)
                ->push(['accepted' => true], 200),
        ]);
        $this->trainer();

        $job = $this->job('queued', '2026-08-25 09:00:00');

        $this->artisan('training:dispatch-queued')->assertSuccessful();
        $this->assertSame('queued', $job->fresh()->status);
        $this->assertNull($job->fresh()->dispatched_at);

        $this->artisan('training:dispatch-queued')->assertSuccessful();
        $this->assertNotNull($job->fresh()->dispatched_at);
    }
}
