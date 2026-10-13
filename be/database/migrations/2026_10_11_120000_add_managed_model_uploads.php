<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->string('managed_model_id', 80)->nullable();
            $table->char('weight_sha256', 64)->nullable();
            $table->json('availability_transition')->nullable();
            $table->unique(['managed_model_id', 'version']);
        });
        Schema::table('analysis_records', fn (Blueprint $table) => $table->json('model_snapshot')->nullable());
        Schema::create('model_uploads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->uuid('tuf_id')->unique();
            $table->json('manifest');
            $table->string('state');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('model_uploads');
        Schema::table('analysis_records', fn (Blueprint $table) => $table->dropColumn('model_snapshot'));
        Schema::table('models', function (Blueprint $table) {
            $table->dropUnique(['managed_model_id', 'version']);
            $table->dropColumn(['managed_model_id', 'weight_sha256', 'availability_transition']);
        });
    }
};
