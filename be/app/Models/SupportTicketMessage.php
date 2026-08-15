<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One message in a support conversation.
 *
 * [from_admin] is stamped when the message is written rather than derived from
 * the author's current role, so promoting someone to administrator later does
 * not turn their old messages into staff replies.
 */
class SupportTicketMessage extends EloquentModel
{
    protected $fillable = [
        'support_ticket_id',
        'user_id',
        'body',
        'from_admin',
    ];

    protected $casts = [
        'from_admin' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function ticket(): BelongsTo
    {
        return $this->belongsTo(SupportTicket::class, 'support_ticket_id');
    }

    /** Null once the author's account has been deleted. */
    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
