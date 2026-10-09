<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Someone asking for an account, from the public landing page.
 *
 * The platform has no self-registration by design — accounts are created by an
 * administrator. This is the queue that makes that reviewable instead of
 * happening over email.
 */
class AccessRequest extends EloquentModel
{
    protected $fillable = [
        'first_name',
        'last_name',
        'email',
        'phone',
        'institution',
        'reason',
        'status',
        'review_note',
        'reviewed_by',
        'reviewed_at',
        'created_user_id',
        'ip_address',
    ];

    protected $casts = [
        'reviewed_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /** The administrator who approved or rejected it. */
    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    /** The account created when this request was approved. */
    public function createdUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_user_id');
    }

    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    public function fullName(): string
    {
        return trim("{$this->first_name} {$this->last_name}");
    }

}
