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
    ];

    protected $casts = [
        'size_bytes' => 'integer',
        'frame_count' => 'integer',
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
}
