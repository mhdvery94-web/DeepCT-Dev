<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Http\Request;
use Illuminate\Notifications\DatabaseNotification;

/**
 * The bell.
 *
 * Everything here is scoped through `$request->user()->notifications()`, so
 * there is no id that could reach somebody else's row — the relation is the
 * authorisation.
 */
class NotificationController extends Controller
{
    private function serialise(DatabaseNotification $notification): array
    {
        $data = $notification->data;

        return [
            'id' => $notification->id,
            'type' => $data['type'] ?? 'general',
            'title' => $data['title'] ?? '',
            'body' => $data['body'] ?? '',
            // Where tapping it should go, in the client's own vocabulary.
            'link' => $data['link'] ?? null,
            'meta' => $data['meta'] ?? [],
            'read' => $notification->read_at !== null,
            'created_at' => $notification->created_at?->toIso8601String(),
        ];
    }

    /** GET /api/notifications */
    public function index(Request $request)
    {
        $perPage = max(1, min((int) $request->input('per_page', 20), 100));

        $query = $request->user()->notifications();

        if ($request->boolean('unread')) {
            $query->whereNull('read_at');
        }

        $notifications = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => collect($notifications->items())
                ->map(fn($n) => $this->serialise($n))
                ->all(),
            'pagination' => [
                'total' => $notifications->total(),
                'per_page' => $notifications->perPage(),
                'current_page' => $notifications->currentPage(),
                'last_page' => $notifications->lastPage(),
                'from' => $notifications->firstItem(),
                'to' => $notifications->lastItem(),
            ],
            'meta' => ['unread' => $request->user()->unreadNotifications()->count()],
        ]);
    }

    /**
     * GET /api/notifications/unread-count — what the client polls.
     *
     * Carries the unread *message* count as well, so the bell and the Messages
     * badge cost one request between them rather than one each. The client
     * polls this every 45 seconds; see ARCHITECTURE.md §4 on why this platform
     * polls rather than holding sockets open.
     */
    public function unreadCount(Request $request)
    {
        $user = $request->user();

        $messages = $user->role === 'admin'
            ? MessageController::unreadConversationCount()
            : Message::whereNull('read_at')
                ->where('from_admin', true)
                ->whereIn(
                    'conversation_id',
                    Conversation::where('user_id', $user->id)->select('id')
                )
                ->count();

        return response()->json([
            'success' => true,
            'data' => [
                'notifications' => $user->unreadNotifications()->count(),
                'messages' => $messages,
            ],
        ]);
    }

    /** POST /api/notifications/{id}/read */
    public function markRead(Request $request, string $id)
    {
        $notification = $request->user()->notifications()->findOrFail($id);
        $notification->markAsRead();

        return response()->json([
            'success' => true,
            'data' => $this->serialise($notification->fresh()),
        ]);
    }

    /** POST /api/notifications/read-all */
    public function markAllRead(Request $request)
    {
        $count = $request->user()->unreadNotifications()->count();
        $request->user()->unreadNotifications->markAsRead();

        return response()->json([
            'success' => true,
            'message' => 'All caught up.',
            'data' => ['marked' => $count],
        ]);
    }

    /** DELETE /api/notifications/{id} */
    public function destroy(Request $request, string $id)
    {
        $request->user()->notifications()->findOrFail($id)->delete();

        return response()->json(['success' => true, 'message' => 'Notification removed.']);
    }

    /** DELETE /api/notifications — clear the list. */
    public function clear(Request $request)
    {
        $count = $request->user()->notifications()->count();
        $request->user()->notifications()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Notifications cleared.',
            'data' => ['deleted' => $count],
        ]);
    }
}
