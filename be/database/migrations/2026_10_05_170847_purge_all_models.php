<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Purge every row in the model registry.
 *
 * Admin management of models is now strictly manual: a row is created by hand
 * through the "Add model" form and removed the same way. There is no longer a
 * "Sync" button that imports rows from a remote catalogue, and the existing
 * rows were left over from that earlier automatic import — entries that no
 * longer match any live deployment and have been superseded by hand-registered
 * endpoints.
 *
 * This is a one-time data migration. `down()` is intentionally a no-op: the
 * purge cannot be "rolled back" without a backup, and pretending otherwise by
 * re-seeding a default row would silently undo the administrator's decision.
 *
 * Foreign keys that reference `models` are declared `on delete set null`
 * (`analysis_records.model_id`) or `on delete cascade` (training job
 * references), so deleting the rows leaves the dependent records intact and
 * self-consistent rather than orphaned with a dangling id.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Nullify every reference before removing the rows they point at. The
        // foreign keys are declared `on delete set null`, so a plain delete
        // would do this too — but doing it explicitly keeps the operation
        // correct even under `SET FOREIGN_KEY_CHECKS = 0`, which the truncate
        // below uses to be atomic and to reset the auto-increment counter.
        DB::table('analysis_records')->whereNotNull('model_id')->update(['model_id' => null]);
        DB::table('user_activities')->whereNotNull('model_id')->update(['model_id' => null]);
        DB::table('training_jobs')
            ->whereNotNull('base_model_id')
            ->orWhereNotNull('trainer_model_id')
            ->orWhereNotNull('resulting_model_id')
            ->update([
                'base_model_id' => null,
                'trainer_model_id' => null,
                'resulting_model_id' => null,
            ]);

        DB::statement('SET FOREIGN_KEY_CHECKS = 0');
        DB::table('models')->truncate();
        DB::statement('SET FOREIGN_KEY_CHECKS = 1');
    }

    public function down(): void
    {
        // Intentionally empty. See the class docblock.
    }
};
