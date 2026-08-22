<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A column that never did anything.
 *
 * `max_concurrent_jobs` appeared in validation rules, in `$fillable`, in the
 * seeder and in tests — and was never compared against anything, anywhere in
 * `app/`. The intent is legible enough: do not send more than N jobs at once
 * to one worker. The limiter was simply never written, so what the column
 * actually did was promise a control that did not exist.
 *
 * Its sibling `current_jobs_count` stays, because that one works: it is
 * incremented when a job starts, decremented when it ends, and read to refuse
 * deleting a model that is busy.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->dropColumn('max_concurrent_jobs');
        });
    }

    public function down(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->integer('max_concurrent_jobs')->default(1)->after('last_health_check');
        });
    }
};
