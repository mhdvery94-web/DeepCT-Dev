<?php

namespace App\Console\Commands;

use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

/**
 * Enforces the retention window on hosted training dataset archives.
 *
 * `predictions:cleanup` has swept prediction output, `temp/downloads` and
 * abandoned `.part` files since the beginning, and it has never touched
 * `training/datasets` — where every hosted run leaves up to 512 MB behind.
 * The only deletion was `DELETE /admin/training/datasets/{id}`: manual, admin
 * only, and nobody was doing it. Fourteen datasets had accumulated 219 MB on
 * this machine by 2 September.
 *
 * WHAT IS SWEPT, AND WHAT IS NOT
 * ------------------------------
 * The archive file, and the rendered previews derived from it. Not the row:
 * a training job points at its dataset, and freeing the disk by deleting the
 * record would leave every run's history pointing at nothing. This is the
 * same split `predictions:cleanup` makes with `files_deleted_at`, for the
 * same reason.
 *
 * A dataset registered by URL owns no archive here and is left entirely
 * alone — there is nothing of ours to free.
 */
class CleanupTrainingDatasets extends Command
{
    protected $signature = 'training:cleanup {--dry-run : List what would be deleted without touching anything}';

    protected $description = 'Delete training dataset archives past their retention window';

    public function handle(): int
    {
        $days = (int) config('training.dataset_retention_days');

        if ($days <= 0) {
            $this->info('Dataset retention is disabled (training.dataset_retention_days is 0).');

            return self::SUCCESS;
        }

        $dryRun = (bool) $this->option('dry-run');
        $cutoff = now()->subDays($days);

        // Narrowed in SQL first: a dataset created after the cutoff is inside
        // the window whatever its jobs did, because `lastActivityAt()` can
        // only move later than `created_at`.
        $candidates = TrainingDataset::with('jobs')
            ->whereNull('archive_deleted_at')
            ->whereNotNull('archive_path')
            ->where('created_at', '<', $cutoff)
            ->get();

        $this->info(
            ($dryRun ? '[dry run] ' : '') .
            "Retention is {$days} day(s); {$candidates->count()} archive(s) to consider."
        );

        $freed = 0;
        $failures = 0;

        foreach ($candidates as $dataset) {
            if ($this->isBusy($dataset)) {
                $this->line("  #{$dataset->id} {$dataset->name}: a job is still using it");
                continue;
            }

            $lastUsed = $dataset->lastActivityAt();

            if ($lastUsed->greaterThanOrEqualTo($cutoff)) {
                $this->line(
                    "  #{$dataset->id} {$dataset->name}: used {$lastUsed->diffForHumans()}"
                );
                continue;
            }

            $freed += $this->sweep($dataset, $lastUsed, $dryRun, $failures);
        }

        $this->info(
            ($dryRun ? 'Would free ' : 'Freed ') . $this->human($freed) .
            ($failures > 0 ? " ({$failures} failure(s))" : '')
        );

        return $failures > 0 ? self::FAILURE : self::SUCCESS;
    }

    /**
     * A worker is holding this dataset, or is about to be handed it.
     *
     * Age does not enter into it. Taking the source away from a run in
     * progress costs GPU hours that cannot be got back; leaving an old archive
     * on disk one more day costs nothing anyone notices.
     */
    private function isBusy(TrainingDataset $dataset): bool
    {
        return $dataset->jobs
            ->whereIn('status', array_merge(TrainingJob::ACTIVE, ['queued']))
            ->isNotEmpty();
    }

    private function sweep(
        TrainingDataset $dataset,
        \Illuminate\Support\Carbon $lastUsed,
        bool $dryRun,
        int &$failures
    ): int {
        $path = $dataset->archive_path;
        $size = Storage::exists($path) ? Storage::size($path) : 0;
        $previews = "training/datasets/preview/{$dataset->id}";
        $size += $this->directorySize($previews);

        $label = "#{$dataset->id} {$dataset->name} (" . $this->human($size)
            . ', last used ' . $lastUsed->diffForHumans() . ')';

        if ($dryRun) {
            $this->line("  would free {$label}");

            return $size;
        }

        try {
            if (Storage::exists($path)) {
                Storage::delete($path);
            }

            // Rendered previews are derived from an archive that is now gone.
            Storage::deleteDirectory($previews);

            // Stamped even when the file had already vanished: the point is to
            // record that the archive is no longer available, so a researcher
            // gets those words rather than an empty list of frames.
            $dataset->update(['archive_deleted_at' => now()]);

            $this->line("  freed {$label}");

            return $size;
        } catch (\Throwable $e) {
            $failures++;
            $this->error("  failed on {$label}: {$e->getMessage()}");

            return 0;
        }
    }

    private function directorySize(string $directory): int
    {
        $total = 0;

        foreach (Storage::allFiles($directory) as $file) {
            $total += Storage::size($file);
        }

        return $total;
    }

    private function human(int $bytes): string
    {
        if ($bytes < 1024) {
            return "{$bytes} B";
        }

        $units = ['KB', 'MB', 'GB'];
        $value = $bytes / 1024;

        foreach ($units as $unit) {
            if ($value < 1024 || $unit === 'GB') {
                return round($value, 1) . " {$unit}";
            }

            $value /= 1024;
        }

        return "{$bytes} B";
    }
}
