<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserActivity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    /**
     * Default password for new users
     */
    const DEFAULT_PASSWORD = 'user12345678';

    /**
     * Display a listing of users with pagination
     */
    public function index(Request $request)
    {
        $perPage = $request->input('per_page', 15);
        $search = $request->input('search');
        $role = $request->input('role');
        $status = $request->input('status');

        $query = User::query();

        // Search by username or email
        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('username', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('name', 'like', "%{$search}%");
            });
        }

        // Filter by role
        if ($role) {
            $query->where('role', $role);
        }

        // Filter by status
        if ($status !== null) {
            $query->where('is_active', $status == 'active' ? 1 : 0);
        }

        $users = $query->orderBy('created_at', 'desc')->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $users->items(),
            'pagination' => [
                'total' => $users->total(),
                'per_page' => $users->perPage(),
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'from' => $users->firstItem(),
                'to' => $users->lastItem(),
            ],
        ]);
    }

    /**
     * Store a newly created user
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'username' => 'required|string|max:255|unique:users',
            'email' => 'required|string|email|max:255|unique:users',
            'role' => ['required', Rule::in(['admin', 'user'])],
            'password' => 'nullable|string|min:8',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        // Use provided password or default
        $password = $request->input('password', self::DEFAULT_PASSWORD);
        $isDefault = $request->input('password') === null;

        $user = User::create([
            'name' => $request->name,
            'username' => $request->username,
            'email' => $request->email,
            'role' => $request->role,
            'password' => Hash::make($password),
            // An account sitting on the published default is effectively
            // public. The platform is the only thing that can insist the
            // researcher picks their own, so it does.
            'must_change_password' => $isDefault,
            'is_active' => true,
        ]);

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'activity_type' => 'create_user',
            'description' => "Created new user: {$user->username}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'created_user_id' => $user->id,
                'role' => $user->role,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'User created successfully',
            'data' => $user,
            'default_password' => $request->input('password') ? null : self::DEFAULT_PASSWORD,
        ], 201);
    }

    /**
     * Display the specified user
     */
    public function show($id)
    {
        $user = User::findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $user,
        ]);
    }

    /**
     * Update the specified user (email, username, role only)
     */
    public function update(Request $request, $id)
    {
        $user = User::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:255',
            'username' => ['sometimes', 'required', 'string', 'max:255', Rule::unique('users')->ignore($user->id)],
            'email' => ['sometimes', 'required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($user->id)],
            'role' => ['sometimes', 'required', Rule::in(['admin', 'user'])],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $oldData = $user->only(['name', 'username', 'email', 'role']);
        $user->update($request->only(['name', 'username', 'email', 'role']));

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'activity_type' => 'update_user',
            'description' => "Updated user: {$user->username}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'updated_user_id' => $user->id,
                'old_data' => $oldData,
                'new_data' => $user->only(['name', 'username', 'email', 'role']),
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'User updated successfully',
            'data' => $user,
        ]);
    }

    /**
     * Remove the specified user from storage (permanent delete)
     */
    public function destroy(Request $request, $id)
    {
        $user = User::findOrFail($id);

        // Prevent deleting yourself
        if ($user->id === auth()->id()) {
            return response()->json([
                'success' => false,
                'message' => 'You cannot delete your own account',
            ], 403);
        }

        $username = $user->username;
        $user->delete();

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'activity_type' => 'delete_user',
            'description' => "Deleted user: {$username}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'deleted_user_id' => $id,
                'username' => $username,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'User deleted successfully',
        ]);
    }

    /**
     * Toggle user active status
     */
    public function toggleStatus(Request $request, $id)
    {
        $user = User::findOrFail($id);

        // Prevent disabling yourself
        if ($user->id === auth()->id()) {
            return response()->json([
                'success' => false,
                'message' => 'You cannot change your own status',
            ], 403);
        }

        $user->is_active = !$user->is_active;
        $user->save();

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'activity_type' => 'toggle_user_status',
            'description' => "Changed user {$user->username} status to " . ($user->is_active ? 'active' : 'inactive'),
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'target_user_id' => $user->id,
                'new_status' => $user->is_active,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'User status updated successfully',
            'data' => [
                'id' => $user->id,
                'is_active' => $user->is_active,
            ],
        ]);
    }

    /**
     * Reset user password to default
     */
    public function resetPassword(Request $request, $id)
    {
        $user = User::findOrFail($id);

        $user->password = Hash::make(self::DEFAULT_PASSWORD);
        // Back on the default, so the same rule applies again: the researcher
        // must choose a new one before reaching the console.
        $user->must_change_password = true;
        $user->save();

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'activity_type' => 'reset_password',
            'description' => "Reset password for user: {$user->username}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'target_user_id' => $user->id,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Password reset to default successfully',
            'default_password' => self::DEFAULT_PASSWORD,
        ]);
    }
}
