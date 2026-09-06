<?php

namespace Tests\Feature;

use App\Services\QueueHealth;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * "Is anything actually consuming the queue?"
 *
 * The class had no tests, and the one it needed most was the false alarm: a
 * single worker part-way through a long interpolation left every job behind it
 * unreserved, which the first version read as "nobody picked this up". So the
 * platform told researchers their work had been abandoned while it was in fact
 * working through their backlog — and a warning that is wrong most of the time
 * teaches people to ignore the time it is right.
 */
class QueueHealthTest extends TestCase
{
    use RefreshDatabase;

    private function queueJob(int $availableSecondsAgo, bool $reserved = false): void
    {
        DB::table('jobs')->insert([
            'queue' => 'default',
            'payload' => '{}',
            'attempts' => 0,
            'reserved_at' => $reserved ? time() : null,
            'available_at' => time() - $availableSecondsAgo,
            'created_at' => time() - $availableSecondsAgo,
        ]);
    }

    public function test_an_empty_queue_is_not_stalled(): void
    {
        $state = app(QueueHealth::class)->inspect();

        $this->assertFalse($state['stalled']);
        $this->assertSame(0, $state['waiting']);
    }

    public function test_a_job_that_has_just_arrived_is_not_stalled(): void
    {
        // A worker claims a job within milliseconds, but "within milliseconds"
        // is not "instantly", and a job queued one second ago says nothing.
        $this->queueJob(2);

        $this->assertFalse(app(QueueHealth::class)->inspect()['stalled']);
    }

    public function test_nothing_consuming_the_queue_is_stalled(): void
    {
        $this->queueJob(QueueHealth::STALL_SECONDS + 30);

        $state = app(QueueHealth::class)->inspect();

        $this->assertTrue($state['stalled']);
        $this->assertSame(1, $state['waiting']);
        $this->assertGreaterThanOrEqual(QueueHealth::STALL_SECONDS, $state['oldest_wait_seconds']);
    }

    public function test_a_busy_worker_is_not_a_stalled_queue(): void
    {
        // One job reserved and running, three waiting behind it — the ordinary
        // state of a queue with one worker and a two-minute job. This is the
        // case that was reported as stalled.
        $this->queueJob(600, reserved: true);
        $this->queueJob(500);
        $this->queueJob(400);
        $this->queueJob(300);

        $state = app(QueueHealth::class)->inspect();

        $this->assertFalse($state['stalled']);
        $this->assertSame(3, $state['waiting']);
    }

    public function test_the_researcher_is_told_the_fact_without_the_command(): void
    {
        $this->queueJob(QueueHealth::STALL_SECONDS + 120);

        $health = app(QueueHealth::class);
        $admin = $health->message();
        $researcher = $health->researcherMessage();

        $this->assertNotNull($admin);
        $this->assertNotNull($researcher);

        // The administrator is the one who can act on it.
        $this->assertStringContainsString('serve:all', $admin);

        // The researcher cannot, and being handed a command reads as an error
        // they caused.
        $this->assertStringNotContainsString('serve:all', $researcher);
        $this->assertStringNotContainsString('administrator', $researcher);
    }

    public function test_neither_message_is_given_when_the_queue_is_healthy(): void
    {
        $this->queueJob(600, reserved: true);

        $health = app(QueueHealth::class);

        $this->assertNull($health->message());
        $this->assertNull($health->researcherMessage());
    }
}
