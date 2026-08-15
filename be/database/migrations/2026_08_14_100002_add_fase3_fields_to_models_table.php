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
        Schema::table('models', function (Blueprint $table) {
            // Add endpoint_url if not exists
            if (!Schema::hasColumn('models', 'endpoint_url')) {
                $table->string('endpoint_url')->nullable()->after('version');
            }
            
            // Modify status if it already exists, or add it
            if (Schema::hasColumn('models', 'status')) {
                // Column exists, we may need to modify it
                // For now, skip modification to avoid issues
            } else {
                $table->enum('status', ['online', 'offline', 'trouble'])->default('offline')->after('endpoint_url');
            }
            
            // Add new health check columns
            if (!Schema::hasColumn('models', 'last_health_check')) {
                $table->timestamp('last_health_check')->nullable()->after('status');
            }
            if (!Schema::hasColumn('models', 'max_concurrent_jobs')) {
                $table->integer('max_concurrent_jobs')->default(1)->after('last_health_check');
            }
            if (!Schema::hasColumn('models', 'current_jobs_count')) {
                $table->integer('current_jobs_count')->default(0)->after('max_concurrent_jobs');
            }
            
            // total_predictions already exists, skip
            
            // Add deployed_at if not exists
            if (!Schema::hasColumn('models', 'deployed_at')) {
                $table->timestamp('deployed_at')->nullable()->after('total_predictions');
            }
            
            if (!Schema::hasColumn('models', 'health_check_error')) {
                $table->text('health_check_error')->nullable()->after('deployed_at');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $columnsToCheck = [
                'endpoint_url',
                'last_health_check',
                'max_concurrent_jobs',
                'current_jobs_count',
                'health_check_error',
            ];
            
            foreach ($columnsToCheck as $column) {
                if (Schema::hasColumn('models', $column)) {
                    $table->dropColumn($column);
                }
            }
            
            // Note: We don't drop status, deployed_at, or total_predictions 
            // as they might have been added by other migrations
        });
    }
};
