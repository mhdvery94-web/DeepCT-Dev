<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Frames a model is trained on.
 *
 * Either an archive sitting on this machine, or a URL the worker fetches for
 * itself. See the migration for why both exist.
 */
class TrainingDataset extends EloquentModel
{
    protected $fillable = [
        'name',
        'description',
        'source_type',
        'archive_path',
        'source_url',
        'size_bytes',
        'frame_count',
        'checksum',
        'uploaded_by',
        'archive_deleted_at',
    ];

    protected $casts = [
        'size_bytes' => 'integer',
        'frame_count' => 'integer',
        'archive_deleted_at' => 'datetime',
    ];

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    public function jobs(): HasMany
    {
        return $this->hasMany(TrainingJob::class);
    }

    public function isHosted(): bool
    {
        return $this->source_type === 'upload';
    }

    /** Held an archive once, and no longer does. */
    public function archiveExpired(): bool
    {
        return $this->archive_deleted_at !== null;
    }

    /**
     * The last moment this dataset was involved in anything.
     *
     * Its own creation, or the newest thing any of its jobs did. The retention
     * window runs from here rather than from `created_at`, because a dataset
     * uploaded in January and trained against last week is in daily use.
     */
    public function lastActivityAt(): \Illuminate\Support\Carbon
    {
        $moments = [$this->created_at];

        foreach ($this->jobs as $job) {
            $moments[] = $job->created_at;
            $moments[] = $job->finished_at;
            $moments[] = $job->heartbeat_at;
        }

        return collect($moments)->filter()->max();
    }
}
