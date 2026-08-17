<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Training becomes something a researcher does, not something an administrator
 * arranges on their behalf.
 *
 * The old shape had datasets registered by an administrator and jobs queued by
 * an administrator, with no training route under `me/` at all. The researcher —
 * the person who actually has data and a question — could not start anything.
 *
 * Three changes carry that:
 *
 * 1. `models.kind` splits the registry in two. A trainer endpoint is registered
 *    exactly like an inference endpoint: a URL, an on/off switch, and the same
 *    health check. Rather than a second table that would duplicate all of it,
 *    the registry gains a column and the queries gain a scope.
 *
 * 2. `training_jobs.trainer_model_id` records which endpoint ran the job, so
 *    "which trainer produced these numbers" survives the URL being changed.
 *
 * 3. `training_metrics` keeps the per-epoch history. `training_jobs.metrics`
 *    holds only the latest report, which answers "how is it doing" and cannot
 *    answer "did it get better" — and the second question is the entire point
 *    of showing a researcher the result.
 *
 * Ownership needed no column: `training_jobs.created_by` already exists and
 * already means "who started this".
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->enum('kind', ['inference', 'trainer'])
                ->default('inference')
                ->after('version');

            $table->index(['kind', 'is_active']);
        });

        Schema::table('training_jobs', function (Blueprint $table) {
            $table->foreignId('trainer_model_id')->nullable()
                ->after('base_model_id')
                ->constrained('models')->nullOnDelete();
        });

        Schema::create('training_metrics', function (Blueprint $table) {
            $table->id();

            $table->foreignId('training_job_id')
                ->constrained('training_jobs')->cascadeOnDelete();

            $table->unsignedInteger('epoch');

            // Free-form for the same reason `training_jobs.metrics` is: what a
            // notebook reports is the notebook's business, and a fixed column
            // set would be wrong before the training code settles.
            $table->json('metrics');

            $table->timestamp('recorded_at');

            // A worker re-reporting an epoch overwrites rather than duplicates.
            // Heartbeats repeat while an epoch is in progress, so without this
            // a long epoch would leave dozens of identical rows.
            $table->unique(['training_job_id', 'epoch']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('training_metrics');

        Schema::table('training_jobs', function (Blueprint $table) {
            $table->dropConstrainedForeignId('trainer_model_id');
        });

        Schema::table('models', function (Blueprint $table) {
            $table->dropIndex(['kind', 'is_active']);
            $table->dropColumn('kind');
        });
    }
};
