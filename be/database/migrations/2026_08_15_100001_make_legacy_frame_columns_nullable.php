<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * `analysis_records` was first designed around a single pair of images:
 * t0_image_path + t2_image_path in, t1_result_path out. The FASE 3 pipeline
 * replaced that with folders (`input_folder` / `output_folder`) holding a whole
 * frame sequence, and never writes the per-image columns.
 *
 * They were still NOT NULL with no default, so every insert from the new upload
 * endpoint failed with:
 *
 *   SQLSTATE[HY000]: General error: 1364 Field 't0_image_path' doesn't have a
 *   default value
 *
 * They are made nullable rather than dropped: existing rows may rely on them,
 * and a single-pair prediction is still a plausible future shortcut.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE analysis_records MODIFY t0_image_path VARCHAR(255) NULL');
        DB::statement('ALTER TABLE analysis_records MODIFY t2_image_path VARCHAR(255) NULL');
    }

    public function down(): void
    {
        // Existing rows may hold NULL by now, so backfill before restoring the
        // constraint or the ALTER fails.
        DB::statement("UPDATE analysis_records SET t0_image_path = '' WHERE t0_image_path IS NULL");
        DB::statement("UPDATE analysis_records SET t2_image_path = '' WHERE t2_image_path IS NULL");

        DB::statement('ALTER TABLE analysis_records MODIFY t0_image_path VARCHAR(255) NOT NULL');
        DB::statement('ALTER TABLE analysis_records MODIFY t2_image_path VARCHAR(255) NOT NULL');
    }
};
