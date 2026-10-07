<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One training run, as the platform sees it.
 *
 * The platform never trains anything. This row is a contract between an
 * administrator who wants a model trained and a GPU worker that can do it.
 */
class TrainingJob extends EloquentModel
{
    protected $fillable = [
        'name',
        'training_dataset_id',
        'base_model_id',
        // Which registered trainer endpoint ran this. Kept separately from
        // `trainer_url` so "which trainer produced these numbers" survives
        // somebody editing the URL afterwards.
        'trainer_model_id',
        'hyperparameters',
        'status',
        'total_epochs',
        'current_epoch',
        'metrics',
        'checkpoint_path',
        'weights_path',
        'error_message',
        'worker_label',
        'trainer_url',
        'claimed_at',
        'dispatched_at',
        'heartbeat_at',
        'started_at',
        'finished_at',
        'resulting_model_id',
        'created_by',
    ];

    protected $casts = [
        'hyperparameters' => 'array',
        'metrics' => 'array',
        'total_epochs' => 'integer',
        'current_epoch' => 'integer',
        'claimed_at' => 'datetime',
        'dispatched_at' => 'datetime',
        'heartbeat_at' => 'datetime',
        'started_at' => 'datetime',
        'finished_at' => 'datetime',
    ];

    /**
     * How long a worker may go quiet before the job is handed to someone else.
     *
     * Generous on purpose: a training epoch on a large dataset can take many
     * minutes, and reclaiming a job that is merely busy would waste the GPU
     * time it has already spent. The worker is expected to beat far more often
     * than this — the window is for a session that has actually died.
     */
    public const STALE_AFTER_MINUTES = 15;

    /** Statuses a worker is actively holding the job in. */
    public const ACTIVE = ['claimed', 'running'];

    /** Nothing more will happen to a job in one of these. */
    public const FINISHED = ['completed', 'failed', 'cancelled'];

    public function dataset(): BelongsTo
    {
        return $this->belongsTo(TrainingDataset::class, 'training_dataset_id');
    }

    public function baseModel(): BelongsTo
    {
        return $this->belongsTo(Model::class, 'base_model_id');
    }

    public function resultingModel(): BelongsTo
    {
        return $this->belongsTo(Model::class, 'resulting_model_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** The registered trainer endpoint that ran this, when one was used. */
    public function trainer(): BelongsTo
    {
        return $this->belongsTo(Model::class, 'trainer_model_id');
    }

    /** Per-epoch history, oldest first — the curve, not the latest figure. */
    public function metricHistory()
    {
        return $this->hasMany(TrainingMetric::class)->orderBy('epoch');
    }

    public function samples()
    {
        return $this->hasMany(TrainingSample::class)->orderBy('epoch');
    }

    /**
     * Delete samples through Eloquent so their files go too.
     *
     * The foreign key cascades the rows on its own, but a database cascade
     * fires no model events, and the PNGs would sit on disk forever with
     * nothing left pointing at them.
     */
    protected static function booted(): void
    {
        static::deleting(function (self $job) {
            $job->samples()->get()->each->delete();
        });
    }

    public function isFinished(): bool
    {
        return in_array($this->status, self::FINISHED, true);
    }

    public function isHeldByWorker(): bool
    {
        return in_array($this->status, self::ACTIVE, true);
    }

    /**
     * Held by a worker that has stopped reporting.
     *
     * Not "failed": the usual cause is a worker session expiring on schedule,
     * which is what this whole system is built around.
     */
    public function scopeStale(Builder $query): Builder
    {
        return $query
            ->whereIn('status', self::ACTIVE)
            ->where(function (Builder $q) {
                $cutoff = now()->subMinutes(self::STALE_AFTER_MINUTES);
                $q->where('heartbeat_at', '<', $cutoff)
                    ->orWhereNull('heartbeat_at');
            });
    }

    /** 0.0–1.0, or null when the job has not said how long it will be. */
    public function progress(): ?float
    {
        if ($this->total_epochs <= 0) return null;

        return min(1.0, $this->current_epoch / $this->total_epochs);
    }
}
