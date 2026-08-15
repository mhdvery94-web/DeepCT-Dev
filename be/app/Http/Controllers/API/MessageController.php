<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\UserActivity;
use App\Services\Notifier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * IT support, as messaging.
 *
 * A researcher has exactly one thread and simply writes in it; there is no
 * subject, no category, no priority and no status to pick before saying what
 * is wrong. An administrator sees every thread as an inbox.
 *
 * The researcher's side never takes a conversation id — it always means "my
 * thread". That removes the whole class of bug where one account reaches
 * another's messages, because there is no id to tamper with.
 */
class MessageController extends Controller
{
    // -------------------------------------------------------------- shaping

    private function serialiseMessage(Message $message, Conversation $conversation): array
    {
        return [
            'id' => $message->id,
            'body' => $message->body,
            'from_admin' => $message->from_admin,
            // A guest message has no author row, so fall back to the name they
            // gave — otherwise an administrator sees an unattributed message.
            'author' => $message->author?->name
                ?? $message->author?->username
                ?? ($message->from_admin ? 'Support' : $conversation->guest_name),
            'author_avatar_url' => $message->author?->avatarUrl(),
            'read_at' => $message->read_at?->toIso8601String(),
            'created_at' => $message->created_at?->toIso8601String(),
        ];
    }

    private function serialise(
        Conversation $conversation,
        bool $withMessages = false,
        bool $forAdmin = false,
    ): array {
        $data = [
            'id' => $conversation->id,
            'name' => $conversation->displayName(),
            'is_guest' => $conversation->isGuest(),
            'guest_email' => $conversation->guest_email,
            'is_archived' => $conversation->is_archived,
            'last_message_at' => $conversation->last_message_at?->toIso8601String(),
            'unread' => $forAdmin
                ? $conversation->unreadForAdmin()
                : $conversation->unreadForUser(),
            'user' => $conversation->relationLoaded('user') && $conversation->user
                ? [
                    'id' => $conversation->user->id,
                    'username' => $conversation->user->username,
                    'name' => $conversation->user->name,
                    'email' => $conversation->user->email,
                    'avatar_url' => $conversation->user->avatarUrl(),
                ]
                : null,
        ];

        if ($forAdmin) {
            $latest = $conversation->relationLoaded('latestMessage')
                ? $conversation->latestMessage
                : $conversation->messages()->latest('id')->first();

            $data['preview'] = $latest
                ? mb_strimwidth(trim(preg_replace('/\s+/', ' ', $latest->body) ?? ''), 0, 120, '...')
                : '';
            $data['last_from_admin'] = $latest?->from_admin;
        }

        if ($withMessages) {
            $data['messages'] = $conversation->messages
                ->map(fn($m) => $this->serialiseMessage($m, $conversation))
                ->all();
        }

        return $data;
    }

    // ------------------------------------------------------------ researcher

    /**
     * GET /api/messages — the caller's thread.
     *
     * Returns an empty thread rather than a 404 when they have never written:
     * "no messages yet" is a state the screen has to render anyway, and
     * creating a row for someone who has said nothing would fill the
     * administrator's inbox with silence.
     */
    public function index(Request $request)
    {
        $conversation = Conversation::with([
            'user:id,username,name,email,avatar_path',
            'messages.author:id,username,name,avatar_path',
        ])->where('user_id', $request->user()->id)->first();

        if (!$conversation) {
            return response()->json([
                'success' => true,
                'data' => [
                    'id' => null,
                    'messages' => [],
                    'unread' => 0,
                    'is_guest' => false,
                ],
            ]);
        }

        return response()->json([
            'success' => true,
            'data' => $this->serialise($conversation, withMessages: true),
        ]);
    }

    /** POST /api/messages — say something. Creates the thread on first use. */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'body' => 'required|string|max:5000',
        ]);

        $user = $request->user();

        // firstOrCreate, not create: the unique index on user_id is the real
        // guarantee, and two rapid taps must not become two threads.
        $conversation = Conversation::firstOrCreate(
            ['user_id' => $user->id],
            ['last_message_at' => now()],
        );

        $message = Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'body' => $validated['body'],
            'from_admin' => false,
        ]);

        $conversation->update([
            'last_message_at' => now(),
            // Writing again pulls the thread back out of the archive; the
            // administrator filed away a conversation, not a person.
            'is_archived' => false,
        ]);

        UserActivity::create([
            'user_id' => $user->id,
            'activity_type' => 'support_message_sent',
            'description' => 'Sent a message to support',
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => ['conversation_id' => $conversation->id],
        ]);

        Notifier::messageFromUser($conversation->fresh()->load('user'), $message);

        return response()->json([
            'success' => true,
            'data' => $this->serialiseMessage($message->load('author'), $conversation),
        ], 201);
    }

    /** POST /api/messages/read — the caller has seen the replies. */
    public function markRead(Request $request)
    {
        $conversation = Conversation::where('user_id', $request->user()->id)->first();

        $marked = $conversation
            ? $conversation->messages()
                ->where('from_admin', true)
                ->whereNull('read_at')
                ->update(['read_at' => now()])
            : 0;

        return response()->json(['success' => true, 'data' => ['marked' => $marked]]);
    }

    // ---------------------------------------------------------------- public

    /**
     * POST /api/messages/public — from the sign-in page.
     *
     * Someone who cannot sign in cannot use the authenticated endpoint, and
     * that is precisely the group most likely to need support. The message
     * lands in the same inbox; the only difference is that the answer goes out
     * by email, because there is no account to show it in.
     *
     * Deliberately *not* attached to an existing account when the address
     * happens to match one: the address is unverified, so attaching it would
     * let anyone drop messages into another researcher's thread.
     */
    public function storePublic(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'email' => 'required|email|max:150',
            'body' => 'required|string|max:5000',
        ]);

        $conversation = Conversation::create([
            'user_id' => null,
            'guest_name' => $validated['name'],
            'guest_email' => $validated['email'],
            'last_message_at' => now(),
        ]);

        $message = Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => null,
            'body' => $validated['body'],
            'from_admin' => false,
        ]);

        Notifier::messageFromGuest($conversation, $message);

        return response()->json([
            'success' => true,
            'message' => 'Message sent. An administrator will reply to '
                . $validated['email'] . '.',
            'data' => ['id' => $conversation->id],
        ], 201);
    }

    // ----------------------------------------------------------------- admin

    /** GET /api/admin/conversations — the inbox. */
    public function adminIndex(Request $request)
    {
        $perPage = max(1, min((int) $request->input('per_page', 20), 100));

        $query = Conversation::with([
            'user:id,username,name,email,avatar_path',
            'latestMessage',
        ]);

        // Archived threads are out of the way by default but never deleted.
        if (!$request->boolean('archived')) {
            $query->where('is_archived', false);
        }

        if ($request->boolean('unread')) {
            $query->whereHas('messages', fn($q) => $q
                ->where('from_admin', false)
                ->whereNull('read_at'));
        }

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('guest_name', 'like', "%{$search}%")
                    ->orWhere('guest_email', 'like', "%{$search}%")
                    ->orWhereHas('user', fn($u) => $u
                        ->where('name', 'like', "%{$search}%")
                        ->orWhere('username', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%"));
            });
        }

        $conversations = $query->recentFirst()->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => collect($conversations->items())
                ->map(fn($c) => $this->serialise($c, forAdmin: true))
                ->all(),
            'pagination' => [
                'total' => $conversations->total(),
                'per_page' => $conversations->perPage(),
                'current_page' => $conversations->currentPage(),
                'last_page' => $conversations->lastPage(),
                'from' => $conversations->firstItem(),
                'to' => $conversations->lastItem(),
            ],
            'meta' => [
                'unread_conversations' => self::unreadConversationCount(),
                'unread_messages' => Message::where('from_admin', false)
                    ->whereNull('read_at')
                    ->count(),
            ],
        ]);
    }

    /** GET /api/admin/conversations/{id} — one thread. */
    public function adminShow($id)
    {
        $conversation = Conversation::with([
            'user:id,username,name,email,avatar_path',
            'messages.author:id,username,name,avatar_path',
        ])->findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $this->serialise($conversation, withMessages: true, forAdmin: true),
        ]);
    }

    /** POST /api/admin/conversations/{id}/reply */
    public function adminReply(Request $request, $id)
    {
        $validated = $request->validate([
            'body' => 'required|string|max:5000',
        ]);

        $conversation = Conversation::with('user')->findOrFail($id);

        $message = Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $request->user()->id,
            'body' => $validated['body'],
            'from_admin' => true,
        ]);

        $conversation->update(['last_message_at' => now()]);

        // Answering is reading: nothing in this thread is still waiting on the
        // administrator once they have replied to it.
        $conversation->messages()
            ->where('from_admin', false)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        Notifier::messageFromAdmin($conversation, $message);

        return response()->json([
            'success' => true,
            'data' => $this->serialiseMessage($message->load('author'), $conversation),
        ], 201);
    }

    /** POST /api/admin/conversations/{id}/read */
    public function adminMarkRead($id)
    {
        $conversation = Conversation::findOrFail($id);

        $marked = $conversation->messages()
            ->where('from_admin', false)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['success' => true, 'data' => ['marked' => $marked]]);
    }

    /** PATCH /api/admin/conversations/{id} — archive or restore. */
    public function adminUpdate(Request $request, $id)
    {
        $validated = $request->validate([
            'is_archived' => 'required|boolean',
        ]);

        $conversation = Conversation::with('user')->findOrFail($id);
        $conversation->update(['is_archived' => $validated['is_archived']]);

        return response()->json([
            'success' => true,
            'message' => $validated['is_archived'] ? 'Archived.' : 'Restored.',
            'data' => $this->serialise($conversation->fresh()->load('user'), forAdmin: true),
        ]);
    }

    /** DELETE /api/admin/conversations/{id} */
    public function adminDestroy($id)
    {
        Conversation::findOrFail($id)->delete();

        return response()->json(['success' => true, 'message' => 'Conversation deleted.']);
    }

    // --------------------------------------------------------------- helpers

    /**
     * Threads holding at least one message an administrator has not read.
     *
     * Shared with the notification counter, which is why it is static and
     * public rather than inlined into the inbox query.
     */
    public static function unreadConversationCount(): int
    {
        return (int) DB::table('messages')
            ->where('from_admin', false)
            ->whereNull('read_at')
            ->distinct()
            ->count('conversation_id');
    }
}
