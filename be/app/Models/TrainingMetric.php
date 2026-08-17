<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model as Eloquent;

/**
 * One epoch's worth of numbers from a training run.
 *
 * `training_jobs.metrics` holds the latest report and nothing else, which
 * answers "how is it doing right now" and cannot answer "did it get better".
 * The second question is the whole reason a researcher is shown the result at
 * all, and it needs the history.
 *
 * The shape of `metrics` is whatever the notebook sends — `loss`, `psnr`,
 * `ssim`, `batches` today. Deliberately not columns: the training code is still
 * research, and a fixed set would be wrong before it settles.
 */
class TrainingMetric extends Eloquent
{
    public $timestamps = false;

    protected $fillable = [
        'training_job_id',
        'epoch',
        'metrics',
        'recorded_at',
    ];

    protected $casts = [
        'metrics' => 'array',
        'recorded_at' => 'datetime',
        'epoch' => 'integer',
    ];

    public function job()
    {
        return $this->belongsTo(TrainingJob::class, 'training_job_id');
    }

    /**
     * Record what a worker reported for an epoch.
     *
     * Heartbeats repeat while an epoch is in progress, so this overwrites
     * rather than appends: without that a long epoch leaves dozens of identical
     * rows and the curve grows a flat step for every minute it took.
     */
    public static function record(int $jobId, int $epoch, ?array $metrics): void
    {
        if ($epoch < 1 || empty($metrics)) {
            return;
        }

        static::updateOrCreate(
            ['training_job_id' => $jobId, 'epoch' => $epoch],
            ['metrics' => $metrics, 'recorded_at' => now()],
        );
    }
}
