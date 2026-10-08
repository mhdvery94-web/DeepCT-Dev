<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Managed model training.
 *
 * The platform **manages** training; it never runs it. Three constraints force
 * that shape and none of them are negotiable: this machine has no GPU and a
 * PHP backend, the worker session that does have a GPU expires every 9–12
 * hours, and training takes days.
 *
 * So a job is a row that a remote worker claims, reports progress against, and
 * hands weights back to. This retired schema remains only as upgrade history;
 * the prediction-only contract is documented in docs/ARCHITECTURE.md.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('training_datasets', function (Blueprint $table) {
            $table->id();

            $table->string('name');
            $table->text('description')->nullable();

            // Two ways to supply data, because they solve different problems.
            //
            // `upload` puts the archive on this machine — fine for a few
            // hundred megabytes. `url` records where the worker should fetch
            // it from instead, which is what a real dataset wants: making 20 GB
            // travel up a home ngrok tunnel and back to the worker is absurd
            // when the worker has a fast link and can pull it directly.
            $table->enum('source_type', ['upload', 'url'])->default('upload');
            $table->string('archive_path')->nullable();
            $table->string('source_url', 2048)->nullable();

            $table->unsignedBigInteger('size_bytes')->nullable();
            $table->unsignedInteger('frame_count')->nullable();
            $table->string('checksum', 64)->nullable();

            $table->foreignId('uploaded_by')->nullable()
                ->constrained('users')->nullOnDelete();

            $table->timestamps();
        });

        Schema::create('training_jobs', function (Blueprint $table) {
            $table->id();

            $table->string('name');

            $table->foreignId('training_dataset_id')
                ->constrained('training_datasets')->cascadeOnDelete();

            // Fine-tuning starts from an existing version rather than noise.
            $table->foreignId('base_model_id')->nullable()
                ->constrained('models')->nullOnDelete();

            $table->json('hyperparameters')->nullable();

            $table->enum('status', [
                'queued',       // waiting for a worker
                'claimed',      // a worker has taken it, not training yet
                'running',      // training, heartbeat fresh
                'completed',
                'failed',       // the worker said so
                'cancelled',    // an administrator said so
            ])->default('queued');

            $table->unsignedInteger('total_epochs')->default(0);
            $table->unsignedInteger('current_epoch')->default(0);

            // Latest reported metrics: loss, psnr, ssim, whatever the notebook
            // sends. Free-form on purpose — the training code does not exist
            // yet, and a fixed column set would be wrong before it is written.
            $table->json('metrics')->nullable();

            // Where the worker's last checkpoint and final weights live.
            $table->string('checkpoint_path')->nullable();
            $table->string('weights_path')->nullable();

            $table->text('error_message')->nullable();

            // Which machine holds it, in the worker's own words ("worker-t4-2").
            $table->string('worker_label', 100)->nullable();

            $table->timestamp('claimed_at')->nullable();

            // The heart of the whole design. A worker that stops reporting has
            // not failed — its worker session expired, which is the normal
            // course of events here — so the job returns to `queued` with its
            // checkpoint intact and the next worker carries on.
            $table->timestamp('heartbeat_at')->nullable();

            $table->timestamp('started_at')->nullable();
            $table->timestamp('finished_at')->nullable();

            // Filled once the finished weights are registered in `models`.
            $table->foreignId('resulting_model_id')->nullable()
                ->constrained('models')->nullOnDelete();

            $table->foreignId('created_by')->nullable()
                ->constrained('users')->nullOnDelete();

            $table->timestamps();

            // The claim query: oldest queued job first.
            $table->index(['status', 'created_at']);
            // The reclaim sweep.
            $table->index(['status', 'heartbeat_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('training_jobs');
        Schema::dropIfExists('training_datasets');
    }
};
