<?php

namespace App\Console\Commands;

use App\Models\TrainingJob;
use App\Services\TrainerDispatcher;
use Illuminate\Console\Command;

/**
 * Send the next queued training run to the trainer, when there is room.
 *
 * A run was dispatched exactly once, at the moment it was created. If that
 * attempt failed — no trainer registered yet, the worker session between
 * restarts, a malformed payload — the job sat at `queued` for ever and nothing
 * ever tried again. Six of them accumulated that way during one afternoon of
 * debugging.
 *
 * That also made the queue position shown to a researcher a lie: a number
 * implies a line that moves, and this one could not. Rather than weaken the
 * display, this makes the queue real.
 *
 * **One at a time.** The trainer holds a single GPU and refuses a second job
 * while it has one, so sending more would only collect refusals. Whether the
 * platform believes a run is in progress is the check used here — `running` is
 * set by the trainer's own first heartbeat, not by us — and `training:reclaim`
 * is what releases a job whose worker went quiet.
 *
 * Oldest first, by `created_at`, which is the same ordering the researcher is
 * shown as their position. Two definitions of "next" would eventually disagree
 * and the disagreement would surface as a queue that jumps.
 */
class DispatchQueuedTraining extends Command
{
    protected $signature = 'training:dispatch-queued';

    protected $description = 'Send the oldest queued training run to the trainer, if it is free';

    public function handle(TrainerDispatcher $dispatcher): int
    {
        if (TrainingJob::where('status', 'running')->exists()) {
            $this->line('A run is already in progress; nothing to send.');

            return self::SUCCESS;
        }

        $job = TrainingJob::where('status', 'queued')
            ->orderBy('created_at')
            ->with('dataset')
            ->first();

        if (!$job) {
            $this->line('The queue is empty.');

            return self::SUCCESS;
        }

        $result = $dispatcher->dispatch($job);

        if ($result['ok']) {
            $this->info("Job {$job->id} sent to the trainer.");

            return self::SUCCESS;
        }

        // Recorded on the job rather than only logged: a run that cannot be
        // sent should say why on the screen its owner is looking at, instead
        // of sitting at `queued` in silence — which is the whole failure this
        // command exists to end.
        $job->update(['error_message' => $result['message']]);

        $this->warn("Job {$job->id} could not be sent: {$result['message']}");

        // Not a command failure. A trainer that is down is an ordinary state
        // here, and a non-zero exit would fill the scheduler's log with alarms
        // about something nobody can fix from this side.
        return self::SUCCESS;
    }
}
