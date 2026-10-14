<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('model_uploads', function (Blueprint $table) {
            $table->uuid('tuf_id')->nullable()->change();
            $table->uuid('intent_id')->nullable()->unique();
            $table->uuid('creation_key')->nullable();
            $table->unsignedBigInteger('availability_revision')->default(0);
            $table->unique(['user_id', 'creation_key']);
        });
    }

    public function down(): void
    {
        if (DB::table('model_uploads')->exists()) {
            throw new RuntimeException('Recovery metadata for retained uploads cannot be rolled back.');
        }
        Schema::table('model_uploads', function (Blueprint $table) {
            // MySQL may reuse the composite owner index for the FK.
            $table->index('user_id', 'model_uploads_owner_retention_index');
        });
        Schema::table('model_uploads', function (Blueprint $table) {
            $table->dropUnique(['user_id', 'creation_key']);
            $table->dropUnique(['intent_id']);
            $table->dropColumn(['intent_id', 'creation_key', 'availability_revision']);
        });

    }
};
