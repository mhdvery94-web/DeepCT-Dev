<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The last step of replacing `username` with `phone`.
 *
 * Nothing reads or writes this column any more — writers moved first, then
 * readers, then the client, each in its own commit with a green suite behind
 * it. What is left is dropping it.
 *
 * **This destroys data.** Every username is gone, here and on the VPS at
 * deploy time. `down()` can bring the column back but not its contents: it
 * refills with `user{id}` purely so the unique constraint can go back on. A
 * rollback is therefore lossy, and there is nothing that can be done about
 * that — the values exist nowhere else.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('username');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable()->after('id');
        });

        // Not the original values. Those are gone.
        DB::table('users')->update(['username' => DB::raw("CONCAT('user', id)")]);

        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable(false)->change();
            $table->unique('username');
        });
    }
};
