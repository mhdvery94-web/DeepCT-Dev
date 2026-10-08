<?php

namespace App\Console\Commands;

use App\Services\StorageGuard;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;

/** One-time deployment cleanup for files belonging to the retired feature. */
class CleanupRetiredData extends Command
{
    protected $signature = 'app:cleanup-retired-data';
    protected $description = 'Remove retired application files after the prediction-only migration';

    public function handle(StorageGuard $guard): int
    {
        if (!$guard->isMounted()) {
            $this->error('Application storage is not mounted. No files removed.');
            return self::FAILURE;
        }
        if (Schema::hasTable('training_jobs') || Schema::hasTable('training_datasets') || Schema::hasColumn('models', 'kind')) {
            $this->error('Run the prediction-only migration before removing retired files.');
            return self::FAILURE;
        }

        $root = realpath(Storage::path(''));
        $retired = realpath(Storage::path('training'));
        if ($retired !== false && ($root === false || $retired !== $root . DIRECTORY_SEPARATOR . 'training')) {
            $this->error('Retired storage directory is not a regular application directory.');
            return self::FAILURE;
        }
        if ($retired !== false && !Storage::deleteDirectory('training')) {
            $this->error('Unable to remove retired files.');
            return self::FAILURE;
        }

        $removed = 0;
        foreach (Storage::allFiles('temp/uploads') as $path) {
            if (!preg_match('~^temp/uploads/\d+/[a-f0-9-]{36}\.json$~D', $path)) continue;
            $resolved = realpath(Storage::path($path));
            if ($resolved === false || $root === false || !str_starts_with($resolved, $root . DIRECTORY_SEPARATOR)) continue;
            $meta = json_decode(Storage::get($path), true);
            if (($meta['purpose'] ?? null) !== 'training') continue;
            if (!Storage::delete([$path, substr($path, 0, -5) . '.part'])) {
                $this->error('Unable to remove a retired upload session.');
                return self::FAILURE;
            }
            $removed++;
        }
        $this->info("Retired application files removed; {$removed} retired upload session(s) cleared.");
        return self::SUCCESS;
    }
}
