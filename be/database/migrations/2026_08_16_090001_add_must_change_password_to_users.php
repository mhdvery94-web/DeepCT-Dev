<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Forces a new account off its default password.
 *
 * Accounts are created by an administrator — or by approving a request from
 * the landing page — and every one of them starts on the same published
 * default, `user12345678`. An account left on it is effectively public,
 * and the platform is the only thing that can insist otherwise.
 *
 * Set when a default password is issued (creation, approval, admin reset),
 * cleared the moment the user picks their own.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('must_change_password')->default(false)->after('password');
        });

        // Existing accounts are not forced: they were created before there was
        // a way to change a password in the app, and locking everyone out of
        // their own console on the next deploy would be a poor trade. Only the
        // seeded demo accounts keep their documented credentials by design.
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('must_change_password');
        });
    }
};
