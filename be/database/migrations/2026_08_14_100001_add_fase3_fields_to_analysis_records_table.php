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
            // Check and add job_id if not exists
            if (!Schema::hasColumn('analysis_records', 'job_id')) {
                $table->string('job_id')->unique()->after('id');
            }
            
            // Check and add model_id if not exists
            if (!Schema::hasColumn('analysis_records', 'model_id')) {
                $table->foreignId('model_id')->nullable()->after('user_id')->constrained('models')->onDelete('set null');
            }
            
            // Add new columns
            if (!Schema::hasColumn('analysis_records', 'input_folder')) {
                $table->string('input_folder')->nullable()->after('file_name');
            }
            if (!Schema::hasColumn('analysis_records', 'output_folder')) {
                $table->string('output_folder')->nullable()->after('input_folder');
            }
            if (!Schema::hasColumn('analysis_records', 'error_message')) {
                $table->text('error_message')->nullable()->after('interpolated_frames');
            }
            if (!Schema::hasColumn('analysis_records', 'input_files_count')) {
                $table->integer('input_files_count')->default(0)->after('error_message');
            }
            if (!Schema::hasColumn('analysis_records', 'output_files_count')) {
                $table->integer('output_files_count')->default(0)->after('input_files_count');
            }
            if (!Schema::hasColumn('analysis_records', 'processing_time_seconds')) {
                $table->integer('processing_time_seconds')->nullable()->after('output_files_count');
            }
            if (!Schema::hasColumn('analysis_records', 'files_deleted_at')) {
                $table->timestamp('files_deleted_at')->nullable()->after('expires_at');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            if (Schema::hasColumn('analysis_records', 'model_id')) {
                $table->dropForeign(['model_id']);
            }
            
            $columnsToCheck = [
                'model_id',
                'job_id',
                'input_folder',
                'output_folder',
                'error_message',
                'input_files_count',
                'output_files_count',
                'processing_time_seconds',
                'files_deleted_at',
            ];
            
            foreach ($columnsToCheck as $column) {
                if (Schema::hasColumn('analysis_records', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
