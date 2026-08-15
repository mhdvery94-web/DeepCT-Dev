<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\SupportTicket;
use App\Models\SupportTicketMessage;
use App\Models\UserActivity;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * In-app IT support.
 *
 * One controller serves both sides. A researcher only ever sees their own
 * tickets — every lookup goes through [findForUser], which scopes by owner
 * unless the caller is an administrator.
 */
class SupportTicketController extends Controller
{
    // ------------------------------------------------------------- shared

    /**
     * A ticket the caller is allowed to see: their own, or any if admin.
     *
     * Scoping in the query rather than checking after loading means another
     * account's ticket 404s instead of 403ing, which does not confirm that
     * the id exists.
     */
    private function findForUser(Request $request, $id): SupportTicket
    {
        $query = SupportTicket::query();

        if ($request->user()->role !== 'admin') {
            $query->where('user_id', $request->user()->id);
        }

        return $query->findOrFail($id);
    }

    private function serialise(SupportTicket $ticket, bool $withMessages = false): array
    {
        $data = [
            'id' => $ticket->id,
            'subject' => $ticket->subject,
            'category' => $ticket->category,
            'status' => $ticket->status,
            'priority' => $ticket->priority,
            'awaiting_admin' => $ticket->awaiting_admin,
            'analysis_record_id' => $ticket->analysis_record_id,
            'message_count' => $ticket->messages()->count(),
            'created_at' => $ticket->created_at?->toIso8601String(),
            'last_reply_at' => $ticket->last_reply_at?->toIso8601String(),
            'resolved_at' => $ticket->resolved_at?->toIso8601String(),
            'user' => $ticket->relationLoaded('user') && $ticket->user
                ? [
                    'id' => $ticket->user->id,
                    'username' => $ticket->user->username,
                    'name' => $ticket->user->name,
                    'email' => $ticket->user->email,
                ]
                : null,
            // Present only for tickets raised from the sign-in page. The
            // administrator answers those by email — see [storePublic].
            'guest' => $ticket->user_id === null
                ? ['name' => $ticket->guest_name, 'email' => $ticket->guest_email]
                : null,
            'is_guest' => $ticket->user_id === null,
        ];

        if ($withMessages) {
            $data['messages'] = $ticket->messages->map(fn($m) => [
                'id' => $m->id,
                'body' => $m->body,
                'from_admin' => $m->from_admin,
                // A guest message has no author row, so fall back to the name
                // they gave — otherwise the admin sees an unattributed reply.
                'author' => $m->author?->name
                    ?? $m->author?->username
                    ?? ($m->from_admin ? null : $ticket->guest_name),
                'created_at' => $m->created_at?->toIso8601String(),
            ])->all();
        }

        return $data;
    }

    // ------------------------------------------------------------- public

    /**
     * POST /api/support/tickets/public — from the sign-in page.
     *
     * Someone who cannot sign in cannot use the authenticated endpoint, and
     * that is precisely the group most likely to need support. The ticket
     * lands in the same admin queue; the only difference is that the reply
     * goes out by email, because there is no account to show it in.
     *
     * Deliberately *not* attached to an existing account when the address
     * happens to match one: the address is unverified, so attaching would let
     * anyone drop messages into another researcher's ticket list.
     */
    public function storePublic(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'email' => 'required|email|max:150',
            'subject' => 'required|string|max:200',
            'category' => ['nullable', Rule::in(SupportTicket::CATEGORIES)],
            'message' => 'required|string|max:5000',
        ]);

        $ticket = SupportTicket::create([
            'user_id' => null,
            'guest_name' => $validated['name'],
            'guest_email' => $validated['email'],
            'subject' => $validated['subject'],
            'category' => $validated['category'] ?? 'account',
            'priority' => 'normal',
            'status' => 'open',
            'last_reply_at' => now(),
            'awaiting_admin' => true,
        ]);

        SupportTicketMessage::create([
            'support_ticket_id' => $ticket->id,
            'user_id' => null,
            'body' => $validated['message'],
            'from_admin' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Ticket submitted. An administrator will reply to '
                . $validated['email'] . '.',
            'data' => ['id' => $ticket->id],
        ], 201);
    }

    // --------------------------------------------------------- researcher

    /** GET /api/support/tickets — the caller's own. */
    public function index(Request $request)
    {
        $perPage = max(1, min((int) $request->input('per_page', 15), 100));

        $query = SupportTicket::with('user:id,username,name,email')
            ->where('user_id', $request->user()->id);

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        $tickets = $query
            ->orderByRaw("FIELD(status, 'open', 'in_progress', 'resolved', 'closed')")
            ->orderByDesc('last_reply_at')
            ->orderByDesc('created_at')
            ->paginate($perPage);

        return $this->paginated($tickets);
    }

    /** POST /api/support/tickets */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'subject' => 'required|string|max:200',
            'category' => ['nullable', Rule::in(SupportTicket::CATEGORIES)],
            'priority' => ['nullable', Rule::in(['low', 'normal', 'high'])],
            'message' => 'required|string|max:5000',
            // Optional, and must belong to the caller — see below.
            'analysis_record_id' => 'nullable|integer',
        ]);

        $analysisId = null;
        if (!empty($validated['analysis_record_id'])) {
            // Only link a job the caller actually owns, otherwise a ticket
            // could be used to probe which job ids exist.
            $owns = $request->user()->id === \App\Models\AnalysisRecord::where(
                'id',
                $validated['analysis_record_id']
            )->value('user_id');

            $analysisId = $owns ? $validated['analysis_record_id'] : null;
        }

        $ticket = SupportTicket::create([
            'user_id' => $request->user()->id,
            'subject' => $validated['subject'],
            'category' => $validated['category'] ?? 'other',
            'priority' => $validated['priority'] ?? 'normal',
            'status' => 'open',
            'analysis_record_id' => $analysisId,
            'last_reply_at' => now(),
            'awaiting_admin' => true,
        ]);

        SupportTicketMessage::create([
            'support_ticket_id' => $ticket->id,
            'user_id' => $request->user()->id,
            'body' => $validated['message'],
            'from_admin' => false,
        ]);

        UserActivity::create([
            'user_id' => $request->user()->id,
            'activity_type' => 'support_ticket_opened',
            'description' => "Opened support ticket: {$ticket->subject}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => ['ticket_id' => $ticket->id, 'category' => $ticket->category],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Ticket submitted. An administrator will reply here.',
            'data' => $this->serialise($ticket->fresh()->load('user')),
        ], 201);
    }

    /** GET /api/support/tickets/{id} — with the conversation. */
    public function show(Request $request, $id)
    {
        $ticket = $this->findForUser($request, $id)
            ->load(['user:id,username,name,email', 'messages.author:id,username,name']);

        return response()->json([
            'success' => true,
            'data' => $this->serialise($ticket, withMessages: true),
        ]);
    }

    /** POST /api/support/tickets/{id}/reply — either side. */
    public function reply(Request $request, $id)
    {
        $validated = $request->validate([
            'body' => 'required|string|max:5000',
        ]);

        $ticket = $this->findForUser($request, $id);

        if ($ticket->status === 'closed') {
            return response()->json([
                'success' => false,
                'message' => 'This ticket is closed. Open a new one to continue.',
            ], 409);
        }

        $isAdmin = $request->user()->role === 'admin';

        SupportTicketMessage::create([
            'support_ticket_id' => $ticket->id,
            'user_id' => $request->user()->id,
            'body' => $validated['body'],
            'from_admin' => $isAdmin,
        ]);

        $ticket->update([
            'last_reply_at' => now(),
            // Whose turn it is now. Drives the admin badge.
            'awaiting_admin' => !$isAdmin,
            // An admin replying picks the ticket up; a researcher replying to
            // a resolved ticket reopens it.
            'status' => $isAdmin
                ? ($ticket->status === 'open' ? 'in_progress' : $ticket->status)
                : ($ticket->status === 'resolved' ? 'in_progress' : $ticket->status),
        ]);

        return response()->json([
            'success' => true,
            'data' => $this->serialise(
                $ticket->fresh()->load(['user', 'messages.author']),
                withMessages: true
            ),
        ], 201);
    }

    // -------------------------------------------------------------- admin

    /** GET /api/admin/support/tickets */
    public function adminIndex(Request $request)
    {
        $perPage = max(1, min((int) $request->input('per_page', 15), 100));

        $query = SupportTicket::with('user:id,username,name,email');

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        if ($request->boolean('awaiting')) {
            $query->where('awaiting_admin', true)->whereIn('status', ['open', 'in_progress']);
        }

        if ($search = $request->input('search')) {
            $query->where('subject', 'like', "%{$search}%");
        }

        $tickets = $query
            ->orderByDesc('awaiting_admin')
            ->orderByRaw("FIELD(status, 'open', 'in_progress', 'resolved', 'closed')")
            ->orderByDesc('last_reply_at')
            ->paginate($perPage);

        return $this->paginated($tickets, [
            'open_count' => SupportTicket::whereIn('status', ['open', 'in_progress'])->count(),
            'awaiting_admin_count' => SupportTicket::where('awaiting_admin', true)
                ->whereIn('status', ['open', 'in_progress'])
                ->count(),
        ]);
    }

    /** PATCH /api/admin/support/tickets/{id} — status and priority. */
    public function updateStatus(Request $request, $id)
    {
        $validated = $request->validate([
            'status' => ['nullable', Rule::in(['open', 'in_progress', 'resolved', 'closed'])],
            'priority' => ['nullable', Rule::in(['low', 'normal', 'high'])],
        ]);

        $ticket = SupportTicket::findOrFail($id);
        $changes = [];

        if (isset($validated['priority'])) {
            $changes['priority'] = $validated['priority'];
        }

        if (isset($validated['status'])) {
            $changes['status'] = $validated['status'];

            if (in_array($validated['status'], ['resolved', 'closed'], true)) {
                $changes['resolved_at'] = now();
                $changes['resolved_by'] = $request->user()->id;
                // Nothing is waiting on the administrator any more.
                $changes['awaiting_admin'] = false;
            } else {
                $changes['resolved_at'] = null;
                $changes['resolved_by'] = null;
            }
        }

        $ticket->update($changes);

        return response()->json([
            'success' => true,
            'data' => $this->serialise($ticket->fresh()->load('user')),
        ]);
    }

    /** DELETE /api/admin/support/tickets/{id} */
    public function destroy($id)
    {
        SupportTicket::findOrFail($id)->delete();

        return response()->json(['success' => true, 'message' => 'Ticket deleted.']);
    }

    // ------------------------------------------------------------ helpers

    private function paginated($paginator, array $meta = [])
    {
        return response()->json([
            'success' => true,
            'data' => collect($paginator->items())
                ->map(fn($t) => $this->serialise($t))
                ->all(),
            'pagination' => [
                'total' => $paginator->total(),
                'per_page' => $paginator->perPage(),
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'from' => $paginator->firstItem(),
                'to' => $paginator->lastItem(),
            ],
            'meta' => $meta,
        ]);
    }
}
