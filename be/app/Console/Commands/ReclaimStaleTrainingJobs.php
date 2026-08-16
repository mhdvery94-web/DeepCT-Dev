<?php

namespace App\Console\Commands;

use App\Models\TrainingJob;
use Illuminate\Console\Command;

/**
 * Hands back training jobs whose worker has gone quiet.
 *
 * A Kaggle session lasts 9–12 hours and training takes days, so a worker
 * disappearing mid-run is the normal course of events. The job is **not**
 * failed: it returns to `queued` with its checkpoint intact, and the next
 * worker resumes from the epoch already reached.
 *
 * Without this, every expired session would strand a job forever and a
 * multi-day training could never finish.
 */
class ReclaimStaleTrainingJobs extends Command
{
    protected $signature = 'training:reclaim';

    protected $description = 'Return training jobs whose worker stopped reporting to the queue';

    public function handle(): int
    {
        $stale = TrainingJob::stale()->get();

        if ($stale->isEmpty()) {
            $this->info('No stale training jobs.');
            return self::SUCCESS;
        }

        foreach ($stale as $job) {
            $lastSeen = $job->heartbeat_at?->diffForHumans() ?? 'never';

            $job->update([
                'status' => 'queued',
                'worker_label' => null,
                'claimed_at' => null,
                // The epoch and the checkpoint stay exactly as they were: they
                // are what the next worker resumes from.
            ]);

            $this->warn(
                "Job #{$job->id} \"{$job->name}\" reclaimed "
                . "(last seen {$lastSeen}, resumes at epoch {$job->current_epoch})"
            );
        }

        $this->info("Reclaimed {$stale->count()} job(s).");

        return self::SUCCESS;
    }
}
