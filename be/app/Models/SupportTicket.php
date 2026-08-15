<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * One reported problem, and the conversation about it.
 */
class SupportTicket extends EloquentModel
{
    protected $fillable = [
        'user_id',
        // Set instead of user_id when the ticket came from the sign-in page,
        // where the reporter is by definition not signed in.
        'guest_name',
        'guest_email',
        'subject',
        'category',
        'status',
        'priority',
        'analysis_record_id',
        'last_reply_at',
        'awaiting_admin',
        'resolved_at',
        'resolved_by',
    ];

    protected $casts = [
        'awaiting_admin' => 'boolean',
        'last_reply_at' => 'datetime',
        'resolved_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /** Categories the UI offers. Free-form in the database on purpose. */
    public const CATEGORIES = [
        'upload',
        'prediction',
        'download',
        'account',
        'other',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function resolver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolved_by');
    }

    /** The job this ticket is about, when there is one. */
    public function analysisRecord(): BelongsTo
    {
        return $this->belongsTo(AnalysisRecord::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(SupportTicketMessage::class)->orderBy('created_at');
    }

    /** Raised from the sign-in page, so there is nobody to reply to in-app. */
    public function isGuest(): bool
    {
        return $this->user_id === null;
    }

    public function isOpen(): bool
    {
        return in_array($this->status, ['open', 'in_progress'], true);
    }

    public function isClosed(): bool
    {
        return in_array($this->status, ['resolved', 'closed'], true);
    }
}
