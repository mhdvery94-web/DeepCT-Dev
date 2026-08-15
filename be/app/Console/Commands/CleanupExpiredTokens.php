<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Laravel\Sanctum\PersonalAccessToken;

class CleanupExpiredTokens extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'tokens:cleanup';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Delete expired API tokens (older than 7 days)';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->info('Cleaning up expired tokens...');

        // Sanctum automatically handles expiration via config
        // But we manually delete tokens older than 7 days for cleanup
        $deleted = PersonalAccessToken::where('created_at', '<', now()->subDays(7))->delete();

        $this->info("Deleted {$deleted} expired token(s).");

        return 0;
    }
}
