<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

class TrainingSample extends Model
{
    protected $fillable = ['training_job_id', 'epoch', 'path'];

    protected $casts = ['epoch' => 'integer'];

    public function job(): BelongsTo
    {
        return $this->belongsTo(TrainingJob::class, 'training_job_id');
    }

    /**
     * The row cascades with its job; the file on disk does not, because a file
     * is not a row and has no foreign key to follow.
     */
    protected static function booted(): void
    {
        static::deleting(function (self $sample) {
            if ($sample->path && Storage::exists($sample->path)) {
                Storage::delete($sample->path);
            }
        });
    }
}
