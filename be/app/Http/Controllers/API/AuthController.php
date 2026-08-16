<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\User;
use App\Models\UserActivity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * Login user and generate token
     *
     * Concurrent sessions are allowed: a researcher may be signed in on a
     * laptop and a phone at once, and each device holds its own token. Tokens
     * expire after 7 days (`config/sanctum.php`) and `tokens:cleanup` removes
     * the expired rows daily.
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

        // Each login gets its own token and existing ones are left alone, so
        // the same account can be signed in on several devices at once.
        // Expiry is handled centrally by `config/sanctum.php` (7 days), and
        // `tokens:cleanup` sweeps the expired rows.
        $token = $user->createToken('auth-token')->plainTextToken;

        // Anything they wrote from the sign-in page, while locked out, becomes
        // part of their own thread now that signing in has proved the address
        // is theirs. Without this the administrator's answer would sit in a
        // thread nobody could ever open.
        Conversation::adoptGuestThreadsFor($user);

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
                'user' => $user->toPublicArray() + [
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
            'data' => $user->toPublicArray() + [
                'last_login_at' => $user->last_login_at,
                'created_at' => $user->created_at,
            ],
        ]);
    }

    /**
     * POST /api/me/password — change your own password.
     *
     * Until now the only way to change a password was for an administrator to
     * reset it to the shared default, which means every account that has ever
     * been helped is sitting on a password the administrator knows. Somebody
     * has to be able to set their own.
     *
     * The current password is required even though the caller is already
     * authenticated: a token left behind on a shared machine should not be
     * enough to take an account over permanently.
     */
    public function changePassword(Request $request)
    {
        $validated = $request->validate([
            'current_password' => 'required|string',
            'password' => ['required', 'confirmed', Password::min(8)],
        ]);

        $user = $request->user();

        if (!Hash::check($validated['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['That is not your current password.'],
            ]);
        }

        if (Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages([
                'password' => ['The new password must be different from the old one.'],
            ]);
        }

        $user->update([
            'password' => Hash::make($validated['password']),
            // Whatever the account was handed to begin with, it is theirs now.
            'must_change_password' => false,
        ]);

        // Every other device is signed out. Concurrent sessions are allowed
        // here by design, but the usual reason to change a password is that
        // someone else may have had it — and leaving their session alive would
        // defeat the whole exercise. The token making this request survives,
        // so the person doing it is not thrown out of their own app.
        $current = $user->currentAccessToken();
        $user->tokens()->where('id', '!=', $current->id)->delete();

        UserActivity::create([
            'user_id' => $user->id,
            'activity_type' => 'password_changed',
            'description' => 'Changed their own password',
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Password changed. Other devices have been signed out.',
        ]);
    }
}
