<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Str;

/**
 * Prints a worker token to paste into `.env` and into the training notebook.
 *
 * Deliberately does not write `.env` itself: rotating this invalidates every
 * running worker, and that should be a decision someone takes with their eyes
 * open rather than a side effect of running a command.
 */
class GenerateTrainingToken extends Command
{
    protected $signature = 'training:token';

    protected $description = 'Generate a shared secret for GPU training workers';

    public function handle(): int
    {
        $token = Str::random(64);

        $this->newLine();
        $this->line('  Add this to <fg=yellow>be/.env</> and restart Octane:');
        $this->newLine();
        $this->line("  <fg=green>TRAINING_WORKER_TOKEN={$token}</>");
        $this->newLine();
        $this->line('  Then give the same value to the training notebook, which');
        $this->line('  sends it as <fg=yellow>Authorization: Bearer …</> on every call.');
        $this->newLine();
        $this->warn('  Changing an existing token stops every running worker.');
        $this->newLine();

        return self::SUCCESS;
    }
}
