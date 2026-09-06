<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Where each generated frame came from.
 *
 * `interpolated_frames` says *which* frames were produced. It cannot say that
 * frame 4 was interpolated from the two scanned frames 1 and 7, while frame 2
 * was interpolated from frame 1 and **frame 4, which the model had just
 * invented**. Those two are not equally trustworthy, and nothing in the record
 * told them apart.
 *
 * A new column rather than a new shape for `interpolated_frames`: changing the
 * type of a field already in the payload is what broke every installed client
 * in 1.25.1, and that lesson was expensive enough to keep.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->json('frame_provenance')
                ->nullable()
                ->after('interpolated_frames');
        });
    }

    public function down(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->dropColumn('frame_provenance');
        });
    }
};
