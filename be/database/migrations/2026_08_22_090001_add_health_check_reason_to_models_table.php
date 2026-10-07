<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A machine-readable reason beside the human-readable one.
 *
 * `health_check_error` holds the checker's own words — "Tunnel is not running
 * (ERR_NGROK_3200)", "Endpoint unreachable (HTTP 502)". Those are the right
 * words for the administrator who has to go and restart the worker session,
 * and the wrong words for a researcher who only wants to know whether they can
 * upload. The client cannot tell one failure from another by parsing that
 * string, so it cannot say anything better than the string itself.
 *
 * This column lets it. The raw message stays exactly as it was and stays on
 * the admin screen; everyone else reads a sentence chosen from this code.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->string('health_check_reason', 20)
                ->nullable()
                ->after('health_check_error');
        });
    }

    public function down(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->dropColumn('health_check_reason');
        });
    }
};
