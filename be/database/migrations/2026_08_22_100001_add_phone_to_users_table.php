<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Step one of replacing `username` with `phone`.
 *
 * Deliberately additive. Dropping `username` here would break every test file
 * that creates a user — thirteen of them — in the same commit that adds the
 * column meant to replace it, leaving no point in the middle where the suite
 * is green and a failure means one thing.
 *
 * So: `phone` appears, `username` stops being required and stops being
 * unique, and everything keeps working. Writers move next, then readers, then
 * the client. `username` is dropped last, once nothing names it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // 30 characters covers an international number with spaces and
            // hyphens. No format validation: Indonesian numbers are written
            // +62, 62 and 0 interchangeably, and rejecting any of those only
            // starts an argument with the form.
            $table->string('phone', 30)->nullable()->after('email');
        });

        // Separate statement: MySQL will not drop a unique index in the same
        // breath as altering the column it covers.
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['username']);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable()->change();
        });
    }

    public function down(): void
    {
        // Anything created after this migration may have a null username, and
        // several may share one. Both have to be resolved before the old
        // constraints can go back on.
        DB::table('users')->whereNull('username')->update([
            'username' => DB::raw("CONCAT('user', id)"),
        ]);

        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable(false)->change();
            $table->unique('username');
            $table->dropColumn('phone');
        });
    }
};
