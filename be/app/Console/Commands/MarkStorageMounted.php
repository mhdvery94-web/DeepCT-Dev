<?php

namespace App\Console\Commands;

use App\Services\StorageGuard;
use Illuminate\Console\Command;

/**
 * Writes the file that proves the storage volume is mounted.
 *
 * Run it once, **after** mounting the share and before switching
 * `STORAGE_REQUIRE_SENTINEL=true` on. Running it while the share is absent
 * would write the sentinel onto the empty mount point instead, which is
 * exactly the state it exists to detect — so the command says so rather than
 * quietly doing it.
 */
class MarkStorageMounted extends Command
{
    protected $signature = 'storage:mark {--force : write it without confirming}';

    protected $description = 'Mark the current storage directory as the mounted results volume';

    public function handle(StorageGuard $guard): int
    {
        $free = $guard->freeBytes();
        $total = $guard->totalBytes();

        $this->line('Storage volume:');
        $this->line('  free  : ' . ($free === null ? 'unknown' : $guard->human($free)));
        $this->line('  total : ' . ($total === null ? 'unknown' : $guard->human($total)));
        $this->newLine();

        // The number is the check. An empty mount point reports the host's own
        // disk, which is usually a very different size from the share.
        $this->warn(
            'Write this only when the numbers above belong to the mounted '
            . 'volume. Writing it onto an unmounted mount point defeats the '
            . 'entire purpose of the file.'
        );

        if (!$this->option('force') && !$this->confirm('Is this the mounted volume?', false)) {
            $this->line('Nothing written.');

            return self::SUCCESS;
        }

        $file = $guard->mark();

        $this->info("Wrote {$file}.");
        $this->line('Now set STORAGE_REQUIRE_SENTINEL=true and run `php artisan config:cache`.');

        return self::SUCCESS;
    }
}
