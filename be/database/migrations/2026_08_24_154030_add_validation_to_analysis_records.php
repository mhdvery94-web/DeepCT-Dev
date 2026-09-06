<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * How good the interpolation actually was, measured on the job's own data.
 *
 * Until now a completed record could say what was generated and how long it
 * took, and nothing at all about whether the frames were any good. A
 * researcher was handed a folder of TIFFs and no basis on which to defend
 * them.
 *
 * The measurement is a hold-out: where the archive happens to contain three
 * consecutive frames, the middle one is set aside, regenerated from its two
 * neighbours, and compared against the frame that was really there. That
 * comparison is the only one available without a separate ground-truth
 * dataset — the frames a researcher wants filled are, by definition, ones
 * nobody has.
 *
 * Null when the archive holds no consecutive triplet, which is a real case and
 * not a failure: an upload of frames 1 and 5 gives nothing to hold out.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->json('validation')
                ->nullable()
                ->after('frame_provenance');
        });
    }

    public function down(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->dropColumn('validation');
        });
    }
};
