<?php

namespace App\Console\Commands;

use App\Models\Model;
use App\Services\ModelHealthChecker;
use Illuminate\Console\Command;

class CheckModelsHealth extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'models:health-check';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Check health status of all active models';

    /**
     * Execute the console command.
     *
     * The probing logic lives in {@see ModelHealthChecker} so this command and
     * ModelController always agree on what "online" means.
     */
    public function handle(ModelHealthChecker $checker)
    {
        $this->info('🔍 Checking health of all active models...');

        $models = Model::where('is_active', true)
            ->whereNotNull('endpoint_url')
            ->get();

        if ($models->isEmpty()) {
            $this->warn('⚠️  No active models found.');

            return 0;
        }

        $results = [
            'online' => 0,
            'offline' => 0,
            'trouble' => 0,
        ];

        // One pooled round rather than one blocking probe per model: with a
        // dead endpoint each probe costs the full timeout, and sequentially
        // that adds up past the ten-second schedule interval.
        $checked = $checker->checkMany($models);

        foreach ($models as $model) {
            $this->line("Checking: {$model->name} ({$model->version})...");

            $result = $checked[$model->id] ?? ['status' => 'offline', 'error' => 'Not probed'];
            $status = $result['status'];
            $results[$status]++;

            $time = isset($result['response_time_ms'])
                ? " ({$result['response_time_ms']}ms)"
                : '';

            match ($status) {
                'online' => $this->info("  ✅ Online{$time}"),
                'trouble' => $this->warn("  ⚠️  Trouble{$time} - " . ($result['error'] ?? '')),
                default => $this->error("  ❌ Offline - " . ($result['error'] ?? 'unknown')),
            };
        }

        $this->newLine();
        $this->info('📊 Summary:');
        $this->line("  ✅ Online: {$results['online']}");
        $this->line("  ⚠️  Trouble: {$results['trouble']}");
        $this->line("  ❌ Offline: {$results['offline']}");

        return 0;
    }
}
