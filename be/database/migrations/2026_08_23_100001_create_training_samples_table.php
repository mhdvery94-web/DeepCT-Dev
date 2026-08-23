<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One rendered frame per epoch, so a researcher can watch the model improve.
 *
 * The trainer runs the generator on a *fixed* test triplet at the end of every
 * epoch. Fixed matters: comparing epoch 3 against epoch 9 on different
 * triplets says nothing about the model, only about the triplets.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('training_samples', function (Blueprint $table) {
            $table->id();
            $table->foreignId('training_job_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('epoch');
            $table->string('path');
            $table->timestamps();

            // A worker that loses its connection and repeats an epoch is the
            // normal course of events here, so a resend must overwrite rather
            // than accumulate.
            $table->unique(['training_job_id', 'epoch']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('training_samples');
    }
};
