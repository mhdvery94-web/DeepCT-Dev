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
 *
 * [read_at] means "read by the other side". Every message has exactly one
 * recipient side — a researcher's message is for the administrators, and a
 * reply is for the researcher — so one column serves both directions.
 */
class Message extends EloquentModel
{
    protected $fillable = [
        'conversation_id',
        'user_id',
        'body',
        'from_admin',
        'read_at',
    ];

    protected $casts = [
        'from_admin' => 'boolean',
        'read_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class);
    }

    /** Null for a guest message, and once the author's account is deleted. */
    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function isRead(): bool
    {
        return $this->read_at !== null;
    }
}
