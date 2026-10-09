<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\AccessRequest;
use App\Models\User;
use App\Models\UserActivity;
use App\Services\Notifier;
use App\Services\PhoneNumber;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

/**
 * The "Join Research" queue.
 *
 * Submission is public — that is the whole point, the applicant has no account
 * yet — so it is rate limited at the route. Everything else needs an admin.
 */
class AccessRequestController extends Controller
{
    /** Handed to accounts created from an approved request. */
    private const DEFAULT_PASSWORD = 'user12345678';

    /**
     * POST /api/access-requests  (public)
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'first_name' => 'required|string|max:100',
            'last_name' => 'required|string|max:100',
            'email' => 'required|email|max:255',
            // Optional in the API for older Flutter clients; required on Next.js.
            'phone' => 'nullable|string|max:30',
            'institution' => 'required|string|max:255',
            'reason' => 'nullable|string|max:2000',
        ]);
        if (!empty($validated['phone']) && PhoneNumber::normalize($validated['phone']) === null) {
            throw \Illuminate\Validation\ValidationException::withMessages([
                'phone' => ['Enter a valid phone number, for example +6281234567890.'],
            ]);
        }

        // Someone who already has an account does not need to apply, and
        // saying so plainly is more useful than a silent duplicate.
        if (User::where('email', $validated['email'])->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'An account already exists for this email. Try signing in instead.',
            ], 409);
        }

        // A second submission while the first is still queued would only give
        // the reviewer two identical rows to read.
        $pending = AccessRequest::where('email', $validated['email'])
            ->where('status', 'pending')
            ->first();

        if ($pending) {
            return response()->json([
                'success' => false,
                'message' => 'A request for this email is already awaiting review.',
            ], 409);
        }

        $accessRequest = AccessRequest::create([
            ...$validated,
            'status' => 'pending',
            'ip_address' => $request->ip(),
        ]);

        // Nobody sits watching the access-request screen; without this the
        // application waits until an administrator happens to look.
        Notifier::accessRequestSubmitted($accessRequest);

        return response()->json([
            'success' => true,
            'message' => 'Request received. An administrator will review it and '
                . 'your account details will be sent to you.',
            'data' => [
                'id' => $accessRequest->id,
                'status' => $accessRequest->status,
                'created_at' => $accessRequest->created_at->toIso8601String(),
            ],
        ], 201);
    }

    /**
     * GET /api/admin/access-requests
     */
    public function index(Request $request)
    {
        $perPage = (int) $request->input('per_page', 15);
        $perPage = max(1, min($perPage, 100));

        $query = AccessRequest::with([
            'reviewer:id,name',
            'createdUser:id,email',
        ]);

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('email', 'like', "%{$search}%")
                    ->orWhere('first_name', 'like', "%{$search}%")
                    ->orWhere('last_name', 'like', "%{$search}%")
                    ->orWhere('institution', 'like', "%{$search}%");
            });
        }

        // Pending first, then newest: the queue is what the admin came for.
        $requests = $query
            ->orderByRaw("FIELD(status, 'pending', 'approved', 'rejected')")
            ->orderByDesc('created_at')
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $requests->items(),
            'pagination' => [
                'total' => $requests->total(),
                'per_page' => $requests->perPage(),
                'current_page' => $requests->currentPage(),
                'last_page' => $requests->lastPage(),
                'from' => $requests->firstItem(),
                'to' => $requests->lastItem(),
            ],
            'meta' => [
                'pending_count' => AccessRequest::where('status', 'pending')->count(),
            ],
        ]);
    }

    /**
     * POST /api/admin/access-requests/{id}/approve
     *
     * Creates the account as part of approving. Marking a request "approved"
     * without creating the user would leave the administrator to do it by hand
     * and the record would mean nothing.
     */
    public function approve(Request $request, $id)
    {
        $accessRequest = AccessRequest::findOrFail($id);

        if (!$accessRequest->isPending()) {
            return response()->json([
                'success' => false,
                'message' => "This request was already {$accessRequest->status}.",
            ], 409);
        }

        if (User::where('email', $accessRequest->email)->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'An account with this email already exists.',
            ], 409);
        }

        $validated = $request->validate([
            'role' => ['nullable', Rule::in(['admin', 'user'])],
            'note' => 'nullable|string|max:1000',
        ]);

        $user = User::create([
            'name' => $accessRequest->fullName(),
            'email' => $accessRequest->email,
            'phone' => $accessRequest->phone,
            'password' => Hash::make(self::DEFAULT_PASSWORD),
            // Handed out with a published default password, so the first sign-in
            // has to replace it before anything else happens.
            'must_change_password' => true,
            'role' => $validated['role'] ?? 'user',
            'is_active' => true,
            'email_verified_at' => now(),
        ]);

        $accessRequest->update([
            'status' => 'approved',
            'review_note' => $validated['note'] ?? null,
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
            'created_user_id' => $user->id,
        ]);

        UserActivity::create([
            'user_id' => $request->user()->id,
            'activity_type' => 'access_request_approved',
            'description' => "Approved access request from {$accessRequest->email}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'access_request_id' => $accessRequest->id,
                'created_user_id' => $user->id,
                'name' => $user->name,
            ],
        ]);

        // They cannot read this until they sign in, which is exactly when it
        // is worth having: the first thing in their bell says they are in.
        Notifier::accountApproved($user);

        return response()->json([
            'success' => true,
            'message' => 'Request approved and account created.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => $user->role,
                ],
                // Shown once so the admin can pass it on; it is not stored
                // anywhere in readable form.
                'default_password' => self::DEFAULT_PASSWORD,
            ],
        ]);
    }

    /**
     * POST /api/admin/access-requests/{id}/reject
     */
    public function reject(Request $request, $id)
    {
        $accessRequest = AccessRequest::findOrFail($id);

        if (!$accessRequest->isPending()) {
            return response()->json([
                'success' => false,
                'message' => "This request was already {$accessRequest->status}.",
            ], 409);
        }

        $validated = $request->validate([
            'note' => 'nullable|string|max:1000',
        ]);

        $accessRequest->update([
            'status' => 'rejected',
            'review_note' => $validated['note'] ?? null,
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
        ]);

        UserActivity::create([
            'user_id' => $request->user()->id,
            'activity_type' => 'access_request_rejected',
            'description' => "Rejected access request from {$accessRequest->email}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => ['access_request_id' => $accessRequest->id],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Request rejected.',
        ]);
    }

    /**
     * DELETE /api/admin/access-requests/{id}
     */
    public function destroy($id)
    {
        AccessRequest::findOrFail($id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'Request deleted.',
        ]);
    }
}
