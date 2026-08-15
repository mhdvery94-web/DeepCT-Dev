<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserActivity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * How long a token may sit unused before its session counts as abandoned.
     *
     * Sanctum stamps `last_used_at` on every authenticated request, so an app
     * left open keeps its session alive simply by being used. The window only
     * has to outlast normal idle gaps between requests, not a working day.
     */
    private const SESSION_IDLE_MINUTES = 15;

    /**
     * Is someone actually using this account right now?
     *
     * A token that was issued but never used counts as active too: it was
     * handed out seconds ago to a client that is still starting up.
     */
    private function hasActiveSession(User $user): bool
    {
        $cutoff = now()->subMinutes(self::SESSION_IDLE_MINUTES);

        return $user->tokens()
            ->whereRaw('COALESCE(last_used_at, created_at) > ?', [$cutoff])
            ->exists();
    }

    /**
     * Login user and generate token
     */
    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $request->email)->first();

        // Check if user exists and is active
        if (!$user) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        if (!$user->is_active) {
            throw ValidationException::withMessages([
                'email' => ['Your account has been deactivated. Please contact administrator.'],
            ]);
        }

        // Verify password
        if (!Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        // SECURITY: one session per account.
        //
        // A login while the account is genuinely in use elsewhere is refused,
        // so two people cannot share credentials without noticing. But a
        // session that was merely abandoned -- app force-closed, browser shut,
        // phone dead -- must not lock the account out until the token expires
        // seven days later. So "in use" means the token was actually exercised
        // recently; anything idle past that window is treated as abandoned and
        // taken over.
        if ($this->hasActiveSession($user)) {
            return response()->json([
                'success' => false,
                'message' => 'This account is already signed in on another device. '
                    . 'Sign out there first, or try again in a few minutes.',
            ], 409);
        }

        // Nothing active: clear whatever was left behind and take over.
        $user->tokens()->delete();

        // Generate new token (expires in 7 days via sanctum config)
        $token = $user->createToken('auth-token')->plainTextToken;

        // Update last login
        $user->update(['last_login_at' => now()]);

        // Log activity
        UserActivity::create([
            'user_id' => $user->id,
            'activity_type' => 'login',
            'description' => 'User logged in',
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'username' => $user->username,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => $user->role,
                    'is_active' => $user->is_active,
                    'last_login_at' => $user->last_login_at,
                ],
                'token' => $token,
            ],
        ]);
    }

    /**
     * Logout user (revoke token)
     */
    public function logout(Request $request)
    {
        // Log activity before logout
        UserActivity::create([
            'user_id' => $request->user()->id,
            'activity_type' => 'logout',
            'description' => 'User logged out',
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        // Revoke current token
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully',
        ]);
    }

    /**
     * Get current authenticated user
     */
    public function me(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $user->id,
                'username' => $user->username,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'is_active' => $user->is_active,
                'last_login_at' => $user->last_login_at,
                'created_at' => $user->created_at,
            ],
        ]);
    }
}
