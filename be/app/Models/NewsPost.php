<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One research news item, shown on the landing page slideshow.
 */
class NewsPost extends EloquentModel
{
    protected $fillable = [
        'title',
        'summary',
        'body',
        'image_path',
        'image_mime',
        'is_published',
        'published_at',
        'sort_order',
        'created_by',
    ];

    protected $casts = [
        'is_published' => 'boolean',
        'published_at' => 'datetime',
        'sort_order' => 'integer',
    ];

    /** Image types accepted on upload. No GD or Imagick here, so nothing is
     * re-encoded — the file is stored exactly as it arrived, which is why the
     * list is narrow and the size limit matters. */
    public const IMAGE_MIMES = ['image/jpeg', 'image/png', 'image/webp'];

    /** 4 MB. A landing-page slide does not need more, and nothing on this
     * machine can shrink an oversized upload. */
    public const MAX_IMAGE_BYTES = 4 * 1024 * 1024;

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** What the public may see. */
    public function scopePublished(Builder $query): Builder
    {
        return $query->where('is_published', true);
    }

    /**
     * Slideshow order: manual `sort_order` first, newest publish date after.
     *
     * Applied identically in the public and admin lists so the admin sees the
     * order the visitor will get.
     */
    public function scopeInSlideOrder(Builder $query): Builder
    {
        return $query
            ->orderBy('sort_order')
            ->orderByDesc('published_at')
            ->orderByDesc('id');
    }

    public function hasImage(): bool
    {
        return $this->image_path !== null;
    }
}
