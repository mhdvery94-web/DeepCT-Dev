<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A shared secret for the inference worker, and a say over TLS.
 *
 * The worker has never had any authentication. On Kaggle behind a randomly
 * named ngrok tunnel that was security by obscurity, and it held — nobody
 * guesses `reaffirm-bullwhip-subzero`. On a workstation sitting on the lab
 * network at a fixed address it holds nothing at all: anyone on that network
 * can spend the GPU, and the platform's own security note already says that
 * knowing the endpoint means bypassing the platform entirely.
 *
 * `auth_token` is sent as `Authorization: Bearer` and stored encrypted, so a
 * database dump does not hand it over. It is write-only through the API: an
 * administrator can set it or clear it and never read it back.
 *
 * `verify_tls` defaults to **false**, which is exactly what the code did
 * before this migration — `withoutVerifying()` was hardcoded in all five
 * places that call a worker, for ngrok and Colab certificates. Defaulting to
 * true here would have switched TLS verification on for a live endpoint
 * nobody had tested it against. The admin form offers it checked for *new*
 * models instead, so the decision is made where someone can see it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->text('auth_token')->nullable()->after('endpoint_url');
            $table->boolean('verify_tls')->default(false)->after('auth_token');
        });
    }

    public function down(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->dropColumn(['auth_token', 'verify_tls']);
        });
    }
};
