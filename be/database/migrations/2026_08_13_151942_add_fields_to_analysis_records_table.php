<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->foreignId('user_id')->nullable()->after('id')->constrained()->onDelete('cascade');
            $table->string('file_name')->nullable()->after('t2_image_path');
            $table->decimal('time_scalar', 5, 3)->default(0.500)->after('file_name');
            $table->text('interpolated_frames')->nullable()->after('t1_result_path'); // JSON array untuk hasil rekursif
            $table->timestamp('expires_at')->nullable()->after('processing_time');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->dropForeign(['user_id']);
            $table->dropColumn(['user_id', 'file_name', 'time_scalar', 'interpolated_frames', 'expires_at']);
        });
    }
};
