<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Marks that the "your results are about to expire" warning has been sent.
 *
 * Output is deleted 24 hours after it is generated, and a job can produce well
 * over a gigabyte — losing it because nobody looked at the app that day is the
 * most expensive thing this platform can do to a researcher.
 *
 * The sweep that deletes expired files runs hourly, so without this column the
 * same warning would be sent every hour for three hours running.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->timestamp('expiry_notified_at')->nullable()->after('expires_at');
        });
    }

    public function down(): void
    {
        Schema::table('analysis_records', function (Blueprint $table) {
            $table->dropColumn('expiry_notified_at');
        });
    }
};
