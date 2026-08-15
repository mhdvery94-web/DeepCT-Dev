<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One interpolation job: an uploaded set of boundary frames, the frames the
 * model generated from them, and the lifecycle around both.
 *
 * Files live under `storage/app/predictions/{user_id}/{job_id}/{input,output}`
 * and are deleted 24 hours after completion by `predictions:cleanup`, which
 * stamps [files_deleted_at] but keeps the record.
 */
class AnalysisRecord extends EloquentModel
{
    protected $fillable = [
        'job_id',
        'user_id',
        'model_id',
        'file_name',
        'input_folder',
        'output_folder',
        'time_scalar',
        't0_image_path',
        't2_image_path',
        't1_result_path',
        'interpolated_frames',
        'error_message',
        'input_files_count',
        'output_files_count',
        'processing_time_seconds',
        'processing_time',
        'status',
        'expires_at',
        'files_deleted_at',
    ];

    /**
     * Without these, `expires_at` comes back from the database as a plain
     * string and every `->toIso8601String()` call on it fails.
     */
    protected $casts = [
        'interpolated_frames' => 'array',
        'time_scalar' => 'decimal:3',
        'input_files_count' => 'integer',
        'output_files_count' => 'integer',
        'processing_time_seconds' => 'integer',
        'expires_at' => 'datetime',
        'files_deleted_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * The inference model that produced this record.
     *
     * Note the explicit class reference: `Model` in this namespace is
     * App\Models\Model, the AI model registry entry, not Eloquent's base class.
     */
    public function model(): BelongsTo
    {
        return $this->belongsTo(Model::class);
    }

    // ------------------------------------------------------------- lifecycle

    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    public function isProcessing(): bool
    {
        return $this->status === 'processing';
    }

    public function isCompleted(): bool
    {
        return $this->status === 'completed';
    }

    public function isFailed(): bool
    {
        return $this->status === 'failed';
    }

    /** True once the 24-hour retention window has passed. */
    public function isExpired(): bool
    {
        return $this->expires_at !== null && $this->expires_at->isPast();
    }

    /** True while the generated files are still on disk. */
    public function hasFiles(): bool
    {
        return $this->files_deleted_at === null;
    }

    /** Root directory holding both `input/` and `output/`. */
    public function storageDirectory(): string
    {
        return "predictions/{$this->user_id}/{$this->job_id}";
    }
}
