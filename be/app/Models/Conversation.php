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

    /**
     * Hand a signed-in account any threads it wrote before it could sign in.
     *
     * Someone locked out writes from the sign-in page, an administrator reads
     * it and fixes their account — and the answer would otherwise be stranded
     * in a thread nobody can open. Adopting it at **login** is what makes an
     * in-app reply reach them, and doing it here rather than at write time is
     * the whole point: signing in proves the address is theirs, so nothing is
     * being taken on the word of an unverified email.
     *
     * @return int how many threads were adopted
     */
    public static function adoptGuestThreadsFor(User $user): int
    {
        $guestThreads = static::whereNull('user_id')
            ->where('guest_email', $user->email)
            ->orderBy('id')
            ->get();

        if ($guestThreads->isEmpty()) {
            return 0;
        }

        $own = static::firstOrCreate(
            ['user_id' => $user->id],
            ['last_message_at' => now()],
        );

        foreach ($guestThreads as $thread) {
            // The author stays null on those messages: they were written by
            // someone not signed in, and rewriting history to say otherwise
            // would be a lie about who typed them.
            Message::where('conversation_id', $thread->id)
                ->update(['conversation_id' => $own->id]);

            $thread->delete();
        }

        $own->update([
            'last_message_at' => $own->messages()->max('created_at') ?? now(),
            'is_archived' => false,
        ]);

        return $guestThreads->count();
    }
}
