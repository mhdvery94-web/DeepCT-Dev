<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Alter activity_type to varchar for flexibility
        DB::statement("ALTER TABLE user_activities MODIFY activity_type VARCHAR(50) NOT NULL");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement("ALTER TABLE user_activities MODIFY activity_type ENUM('login', 'logout', 'prediction', 'download', 'delete') NOT NULL");
    }
};
