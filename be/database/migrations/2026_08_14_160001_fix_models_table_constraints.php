<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Fixes two blocking defects on the `models` table:
     *
     * 1. `file_path` was NOT NULL with no default, but ModelController::store()
     *    never sets it. Under STRICT_TRANS_TABLES every insert failed with
     *    "Field 'file_path' doesn't have a default value" (HTTP 500).
     *    Models are now deployed remotely (Kaggle/Colab) and identified by
     *    `endpoint_url`, so a local file path is optional.
     *
     * 2. `status` was enum('online','offline','error') but the application
     *    writes 'trouble' (slow health check response). Under strict mode this
     *    raised "Data truncated for column 'status'".
     */
    public function up(): void
    {
        if (! Schema::hasTable('models')) {
            return;
        }

        // 1. Make file_path nullable (remote-deployed models have no local file).
        if (Schema::hasColumn('models', 'file_path')) {
            DB::statement('ALTER TABLE `models` MODIFY `file_path` VARCHAR(255) NULL');
        }

        // 2. Normalise any legacy 'error' value before narrowing the enum.
        if (Schema::hasColumn('models', 'status')) {
            DB::table('models')->where('status', 'error')->update(['status' => 'offline']);

            DB::statement(
                "ALTER TABLE `models` MODIFY `status` ENUM('online','offline','trouble') NOT NULL DEFAULT 'offline'"
            );
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (! Schema::hasTable('models')) {
            return;
        }

        if (Schema::hasColumn('models', 'status')) {
            // 'trouble' does not exist in the original enum; fold it back to 'error'.
            DB::table('models')->where('status', 'trouble')->update(['status' => 'offline']);

            DB::statement(
                "ALTER TABLE `models` MODIFY `status` ENUM('online','offline','error') NOT NULL DEFAULT 'offline'"
            );
        }

        if (Schema::hasColumn('models', 'file_path')) {
            // Restoring NOT NULL requires a concrete value for existing rows.
            DB::table('models')->whereNull('file_path')->update(['file_path' => '']);

            DB::statement('ALTER TABLE `models` MODIFY `file_path` VARCHAR(255) NOT NULL');
        }
    }
};
