<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * When a dataset archive was swept off disk.
 *
 * The same shape as `analysis_records.files_deleted_at`, and for the same
 * reason: a training job points at its dataset, so deleting the row to free
 * the disk would leave the run's history pointing at nothing. The archive
 * goes, the record stays, and this column is what tells the difference
 * between "never had one" and "had one, and it expired".
 *
 * `archive_path` is deliberately left as it was. What the file was called is
 * part of the record, and blanking it would make an expired dataset
 * indistinguishable from one registered by URL.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('training_datasets', function (Blueprint $table) {
            $table->timestamp('archive_deleted_at')->nullable()->after('checksum');
        });
    }

    public function down(): void
    {
        Schema::table('training_datasets', function (Blueprint $table) {
            $table->dropColumn('archive_deleted_at');
        });
    }
};
