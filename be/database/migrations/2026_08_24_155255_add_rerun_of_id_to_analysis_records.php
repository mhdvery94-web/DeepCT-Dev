<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Which earlier job this one is a second opinion on.
 *
 * The model registry has always been able to hold more than one inference
 * endpoint, health-check them and switch between them — but there was no way
 * to put two of them on the same frames and see which did better. The registry
 * was plumbing; this is what makes it an instrument.
 *
 * A re-run is a full job of its own: its own record, its own folders, its own
 * queue slot and its own hold-out measurement. Only the input frames are
 * shared, copied rather than referenced, so deleting either job cannot leave
 * the other pointing at frames that are gone.
 *
 * `nullOnDelete`, because losing the original must not take the comparison
 * with it — the numbers on the re-run are still numbers.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->foreignId('rerun_of_id')
                ->nullable()
                ->after('model_id')
                ->constrained('analysis_records')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->dropForeign(['rerun_of_id']);
            $table->dropColumn('rerun_of_id');
        });
    }
};
