<?php

namespace App\Services;

use Illuminate\Support\Facades\Storage;

/**
 * Refuses work the disk cannot hold, and notices when the disk is not there.
 *
 * Two different failures, both silent until now.
 *
 * **Full.** Nothing checked free space before accepting an archive. A 2 GB
 * upload onto a machine with 3 GB left succeeds, generates more frames than it
 * received, and stops with the disk at zero — at which point MySQL cannot
 * write, the queue cannot record the failure, and the log that would explain
 * it cannot be written either. On a lab server that is an afternoon; on a
 * Raspberry Pi sharing one card between root, database and results it is the
 * whole machine.
 *
 * **Absent.** When results live on a NAS, an unmounted share is not an error —
 * it is an ordinary empty directory, and `Storage::put()` writes into it
 * without complaint. The frames go onto the host's own disk, the researcher
 * sees a successful job, and the files are somewhere nobody will look. A
 * sentinel file that exists only on the mount is how that gets caught.
 */
class StorageGuard
{
    /**
     * Bytes free on the volume the storage disk lives on, or null where the
     * platform will not say.
     */
    public function freeBytes(): ?int
    {
        $free = @disk_free_space($this->root());

        return is_float($free) || is_int($free) ? (int) $free : null;
    }

    public function totalBytes(): ?int
    {
        $total = @disk_total_space($this->root());

        return is_float($total) || is_int($total) ? (int) $total : null;
    }

    /**
     * Whether the storage root is the volume it is supposed to be.
     *
     * Always true when the check is switched off, which is the default: a
     * single-disk install has nothing to be absent, and demanding a sentinel
     * nobody created would refuse every upload.
     */
    public function isMounted(): bool
    {
        if (!config('storage_guard.require_sentinel')) {
            return true;
        }

        return Storage::exists((string) config('storage_guard.sentinel_file'));
    }

    /** Writes the sentinel. Run once, after mounting. */
    public function mark(): string
    {
        $file = (string) config('storage_guard.sentinel_file');

        Storage::put(
            $file,
            "Written by `php artisan storage:mark`.\n" .
            "Proves this directory is the mounted storage volume and not the\n" .
            "empty mount point left behind when the share is absent.\n" .
            "Do not delete, and do not copy it to the mount point itself.\n"
        );

        return $file;
    }

    /**
     * How much room an upload of [$uploadBytes] needs before it is accepted.
     *
     * The multiplier is not a safety margin — it is the actual cost. See
     * `config/storage_guard.php`.
     */
    public function requiredBytesFor(int $uploadBytes): int
    {
        return (int) ceil(
            $uploadBytes * (float) config('storage_guard.headroom_multiplier', 3.0)
        );
    }

    /**
     * Null when there is room, or a sentence explaining why there is not.
     *
     * A sentence rather than an exception because both callers — the plain
     * upload and the chunked one — already answer with a message and a status
     * code, and neither wants to catch something to do it.
     */
    public function refusalFor(int $uploadBytes): ?string
    {
        if (!$this->isMounted()) {
            return 'Storage is not available: the results volume is not mounted. '
                . 'An administrator needs to remount it before uploads can be accepted.';
        }

        $free = $this->freeBytes();

        // Some filesystems will not report, and refusing every upload because
        // a number could not be read would be worse than the risk it guards.
        if ($free === null) {
            return null;
        }

        $required = $this->requiredBytesFor($uploadBytes);
        $floor = (int) config('storage_guard.minimum_free_bytes');

        if ($free - $required < $floor) {
            return sprintf(
                'Not enough space to accept this upload. It needs about %s '
                . 'once the generated frames and the results archive are '
                . 'accounted for, and only %s is free. Older results are '
                . 'deleted 24 hours after they are made; an administrator can '
                . 'also free space now.',
                $this->human($required),
                $this->human($free)
            );
        }

        return null;
    }

    /** Bytes held under one storage directory, or 0 when it does not exist. */
    public function bytesUnder(string $directory): int
    {
        return collect(Storage::allFiles($directory))
            ->sum(fn(string $file) => Storage::size($file));
    }

    /**
     * What the admin console needs to answer "how much room is left".
     *
     * With results on a NAS that stops being a curiosity and becomes a daily
     * question, and the answer that matters is not the total — it is how much
     * of what is used will come back on its own. A disk at 90% with most of it
     * expiring within the day is a different situation from a disk at 90% of
     * datasets that will never expire, and a single "used" figure cannot tell
     * them apart.
     *
     * @return array<string, mixed>
     */
    public function report(): array
    {
        $free = $this->freeBytes();
        $total = $this->totalBytes();

        $predictions = $this->bytesUnder('predictions');
        $evidence = $this->bytesUnder('prediction-evidence');
        $temp = $this->bytesUnder('temp');

        return [
            'mounted' => $this->isMounted(),
            'sentinel_enforced' => (bool) config('storage_guard.require_sentinel'),

            'free_bytes' => $free,
            'total_bytes' => $total,
            'used_bytes' => $free !== null && $total !== null ? $total - $free : null,
            'free_human' => $free === null ? null : $this->human($free),
            'total_human' => $total === null ? null : $this->human($total),

            'minimum_free_bytes' => (int) config('storage_guard.minimum_free_bytes'),
            'headroom_multiplier' => (float) config('storage_guard.headroom_multiplier'),

            'breakdown' => [
                // Reclaimed by `predictions:cleanup` 24 hours after each job.
                'predictions' => $predictions,
                // Kept for good, and small on purpose: a few hundred kilobytes
                // per run.
                'evidence' => $evidence,
                'temporary' => $temp,
            ],
        ];
    }

    public function human(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $value = (float) $bytes;
        $unit = 0;

        while ($value >= 1024 && $unit < count($units) - 1) {
            $value /= 1024;
            $unit++;
        }

        return round($value, $unit === 0 ? 0 : 1) . ' ' . $units[$unit];
    }

    private function root(): string
    {
        return Storage::path('');
    }
}
