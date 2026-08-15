<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * One thread between a person and the administrators.
 *
 * There is exactly one per account — support here is a conversation, not a
 * queue of tickets, so a researcher with a second problem simply keeps typing
 * in the same thread. Someone who cannot sign in gets a thread of their own
 * carrying the name and address they gave.
 */
class Conversation extends EloquentModel
{
    protected $fillable = [
        'user_id',
        'guest_name',
        'guest_email',
        'last_message_at',
        'is_archived',
    ];

    protected $casts = [
        'is_archived' => 'boolean',
        'last_message_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class)->orderBy('created_at');
    }

    /** Powers the inbox preview line without loading every message. */
    public function latestMessage(): HasOne
    {
        return $this->hasOne(Message::class)->latestOfMany();
    }

    /** Raised from the sign-in page, so there is nobody to reply to in-app. */
    public function isGuest(): bool
    {
        return $this->user_id === null;
    }

    /** Whoever is on the other end of this thread, as a name to show. */
    public function displayName(): string
    {
        if ($this->isGuest()) {
            return $this->guest_name ?: 'Guest';
        }

        return $this->user?->name ?? $this->user?->username ?? "User #{$this->user_id}";
    }

    /** Messages from the person, still unread by an administrator. */
    public function unreadForAdmin(): int
    {
        return $this->messages()
            ->where('from_admin', false)
            ->whereNull('read_at')
            ->count();
    }

    /** Replies from an administrator, still unread by the person. */
    public function unreadForUser(): int
    {
        return $this->messages()
            ->where('from_admin', true)
            ->whereNull('read_at')
            ->count();
    }

    /** Newest activity first — the only order an inbox is ever read in. */
    public function scopeRecentFirst(Builder $query): Builder
    {
        return $query->orderByDesc('last_message_at')->orderByDesc('id');
    }
}
