<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ai_requests', function (Blueprint $table) {
            // Intentionally no FK: deletion must not erase the admitted selection.
            $table->unsignedBigInteger('requested_analysis_record_id')->nullable()->after('analysis_record_id');
        });
        // Recover only selections whose original FK still exists. Do not infer
        // deleted historical IDs from source snapshots or generated prose.
        DB::table('ai_requests')->whereNotNull('analysis_record_id')
            ->update(['requested_analysis_record_id' => DB::raw('analysis_record_id')]);
    }

    public function down(): void
    {
        Schema::table('ai_requests', function (Blueprint $table) {
            $table->dropColumn('requested_analysis_record_id');
        });
    }
};
