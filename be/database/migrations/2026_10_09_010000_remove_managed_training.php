<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Retire managed training while preserving inference models and predictions. */
return new class extends Migration
{
    public function up(): void
    {
        // Drop children before their parents; never disable foreign-key checks.
        foreach (['training_samples', 'training_metrics', 'training_jobs', 'training_datasets'] as $table) {
            Schema::dropIfExists($table);
        }

        if (Schema::hasColumn('models', 'kind')) {
            DB::table('models')->where('kind', 'trainer')->delete();
            foreach (Schema::getIndexes('models') as $index) {
                if (in_array('kind', $index['columns'], true)) {
                    Schema::table('models', fn (Blueprint $table) => $table->dropIndex($index['name']));
                }
            }
            Schema::table('models', fn (Blueprint $table) => $table->dropColumn('kind'));
        }

        DB::table('user_activities')->where('activity_type', 'like', 'training\_%')->delete();
    }

    public function down(): void
    {
        // This intentionally removes data. Recovery requires the pre-deploy
        // database backup and the previous application release, not empty tables.
        throw new RuntimeException('Managed-training removal requires restoring the pre-deploy backup to roll back.');
    }
};
