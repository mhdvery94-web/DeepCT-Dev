<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * A state for "the files are here" that is not yet "waiting for a worker".
 *
 * Upload and analysis used to be one button: PredictionIntake created the
 * record as `pending` and dispatched in the same breath. The preview a
 * researcher asked for has to sit between those two things — look at what you
 * are about to submit, then submit it — so there has to be a state where the
 * frames exist and nothing is queued.
 *
 * `uploaded` goes in front of `pending` rather than after it. Everything that
 * counts the queue asks for `pending` and keeps working untouched.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement(
            "ALTER TABLE analysis_records MODIFY COLUMN status "
            . "ENUM('uploaded','pending','processing','completed','failed') "
            . "NOT NULL DEFAULT 'pending'"
        );
    }

    public function down(): void
    {
        // Anything still sitting at `uploaded` was never analysed. It becomes
        // `pending` so the column can narrow again — which means a rollback
        // queues work nobody confirmed. There is no better answer: the state
        // stops existing.
        DB::table('analysis_records')
            ->where('status', 'uploaded')
            ->update(['status' => 'pending']);

        DB::statement(
            "ALTER TABLE analysis_records MODIFY COLUMN status "
            . "ENUM('pending','processing','completed','failed') "
            . "NOT NULL DEFAULT 'pending'"
        );
    }
};
