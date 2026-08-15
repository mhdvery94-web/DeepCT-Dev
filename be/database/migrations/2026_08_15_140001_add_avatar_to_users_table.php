<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Profile photos.
 *
 * Stored on the local disk and served through an authenticated endpoint, the
 * same as research-news images and for the same reason: no `storage:link` on
 * this machine, and the app is reached over ngrok.
 *
 * Nullable, and staying that way — an account with no photo shows an initials
 * frame, which is a deliberate design, not a placeholder waiting to be filled.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar_path')->nullable()->after('role');
            $table->string('avatar_mime', 60)->nullable()->after('avatar_path');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['avatar_path', 'avatar_mime']);
        });
    }
};
