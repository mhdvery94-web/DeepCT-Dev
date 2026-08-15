<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('models', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('version');
            $table->string('file_path'); // Path ke file .h5
            $table->enum('status', ['online', 'offline', 'error'])->default('offline');
            $table->decimal('accuracy', 5, 2)->nullable(); // Akurasi model (0-100%)
            $table->text('description')->nullable();
            $table->integer('total_predictions')->default(0); // Jumlah prediksi yang sudah dilakukan
            $table->timestamp('deployed_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('models');
    }
};
