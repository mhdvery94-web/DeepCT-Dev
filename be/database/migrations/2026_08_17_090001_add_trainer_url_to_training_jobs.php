<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Lets a job be *pushed* to a trainer, the same way a prediction is pushed to
 * a model endpoint.
 *
 * Until now the only way to start training was for a worker to poll `claim`.
 * That still works and is still the safety net, but it means someone has to go
 * and start a poller. Registering a trainer URL and pressing a button in the
 * console is what an administrator actually expects, and it mirrors how
 * inference already works.
 *
 * Recorded per job rather than only in config: over months a project runs
 * against several notebooks, and "which machine trained this?" is a question
 * the row should be able to answer by itself.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('training_jobs', function (Blueprint $table) {
            $table->string('trainer_url', 500)->nullable()->after('worker_label');
            $table->timestamp('dispatched_at')->nullable()->after('claimed_at');
        });
    }

    public function down(): void
    {
        Schema::table('training_jobs', function (Blueprint $table) {
            $table->dropColumn(['trainer_url', 'dispatched_at']);
        });
    }
};
