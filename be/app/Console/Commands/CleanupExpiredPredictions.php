<?php

namespace App\Console\Commands;

use App\Models\AnalysisRecord;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

/**
 * Enforces the 24-hour retention window on prediction output.
 *
 * Files are deleted; the database record is kept and stamped with
 * `files_deleted_at` so the user still sees the job in their history and gets
 * a clear "expired" message instead of a broken download.
 */
class CleanupExpiredPredictions extends Command
{
    protected $signature = 'predictions:cleanup {--dry-run : List what would be deleted without touching anything}';

    protected $description = 'Delete prediction files past their 24-hour retention window';

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');

        $expired = AnalysisRecord::whereNotNull('expires_at')
            ->where('expires_at', '<=', now())
            ->whereNull('files_deleted_at')
            ->get();

        $this->info(
            ($dryRun ? '[dry run] ' : '') .
            "Found {$expired->count()} expired prediction(s)."
        );

        $freedBytes = 0;
        $failures = 0;

        // Note: the temp sweeps below run whether or not anything expired.
        // Returning early on an empty set would let abandoned uploads and
        // orphaned download archives accumulate forever on an installation
        // where nothing has reached its retention window yet.
        foreach ($expired as $record) {
            $directory = $record->storageDirectory();
            $size = $this->directorySize($directory);

            if ($dryRun) {
                $this->line("  would delete {$directory} (" . $this->human($size) . ')');
                $freedBytes += $size;
                continue;
            }

            try {
                Storage::deleteDirectory($directory);

                // Stamp even when the directory was already gone: the point is
                // to record that the files are no longer available.
                $record->update(['files_deleted_at' => now()]);

                $freedBytes += $size;
                $this->line("  deleted {$directory} (" . $this->human($size) . ')');
            } catch (\Throwable $e) {
                $failures++;
                $this->error("  failed on {$directory}: {$e->getMessage()}");
            }
        }

        $freedBytes += $this->sweepStaleDownloads($dryRun);
        $freedBytes += $this->sweepAbandonedUploads($dryRun);

        $this->info(
            ($dryRun ? 'Would free ' : 'Freed ') . $this->human($freedBytes) .
            ($failures > 0 ? " ({$failures} failure(s))" : '')
        );

        return $failures > 0 ? self::FAILURE : self::SUCCESS;
    }

    /**
     * Remove leftover on-demand download ZIPs.
     *
     * `AnalysisController` deletes each one in a terminating callback, but a
     * request that dies mid-flight never gets there. These are full-size
     * copies of the results, so a safety net is worth having.
     */
    private function sweepStaleDownloads(bool $dryRun): int
    {
        $cutoff = now()->subHour()->getTimestamp();
        $freed = 0;

        foreach (Storage::allFiles('temp/downloads') as $file) {
            try {
                if (Storage::lastModified($file) > $cutoff) {
                    continue; // Possibly still being downloaded.
                }

                $size = Storage::size($file);

                if ($dryRun) {
                    $this->line('  would delete stale download ' . basename($file) .
                        ' (' . $this->human($size) . ')');
                } else {
                    Storage::delete($file);
                    $this->line('  deleted stale download ' . basename($file) .
                        ' (' . $this->human($size) . ')');
                }

                $freed += $size;
            } catch (\Throwable) {
                // Raced with another cleanup or the request itself; ignore.
            }
        }

        return $freed;
    }

    /**
     * Remove chunked-upload sessions nobody came back for.
     *
     * A user who closes the app mid-upload leaves a `.part` file that can run
     * to hundreds of megabytes. The window is deliberately generous — resuming
     * an interrupted upload is a supported feature, and deleting a session
     * someone is still working through would be worse than the wasted space.
     */
    private function sweepAbandonedUploads(bool $dryRun): int
    {
        $cutoff = now()->subDay()->getTimestamp();
        $freed = 0;

        foreach (Storage::allFiles('temp/uploads') as $file) {
            try {
                if (Storage::lastModified($file) > $cutoff) {
                    continue;
                }

                $size = Storage::size($file);

                if ($dryRun) {
                    $this->line('  would delete abandoned upload ' . basename($file) .
                        ' (' . $this->human($size) . ')');
                } else {
                    Storage::delete($file);
                    $this->line('  deleted abandoned upload ' . basename($file) .
                        ' (' . $this->human($size) . ')');
                }

                $freed += $size;
            } catch (\Throwable) {
                // Raced with the uploader itself; leave it for the next run.
            }
        }

        return $freed;
    }

    private function directorySize(string $directory): int
    {
        $bytes = 0;

        foreach (Storage::allFiles($directory) as $file) {
            try {
                $bytes += Storage::size($file);
            } catch (\Throwable) {
                // A file that vanished between listing and sizing is fine.
            }
        }

        return $bytes;
    }

    private function human(int $bytes): string
    {
        if ($bytes < 1024) return "{$bytes} B";
        if ($bytes < 1048576) return round($bytes / 1024, 1) . ' KB';
        if ($bytes < 1073741824) return round($bytes / 1048576, 1) . ' MB';

        return round($bytes / 1073741824, 2) . ' GB';
    }
}
