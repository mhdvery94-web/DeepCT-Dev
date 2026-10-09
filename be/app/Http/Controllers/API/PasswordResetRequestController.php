<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Services\Notifier;
use App\Services\PhoneNumber;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PasswordResetRequestController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'email' => 'required|email|max:255',
            'phone' => 'required|string|max:30',
        ]);
        $phone = PhoneNumber::normalize($validated['phone']);
        if ($phone === null) {
            throw ValidationException::withMessages(['phone' => ['Enter a valid phone number, for example +6281234567890.']]);
        }

        $user = User::whereRaw('LOWER(email) = ?', [strtolower(trim($validated['email']))])
            ->where('is_active', true)->first();
        if (!$user || PhoneNumber::normalize($user->phone) !== $phone) {
            return response()->json([
                'success' => false,
                'message' => 'User not found. The email and phone number must match the same active account.',
            ], 404);
        }

        // A matching phone/email locates an account; it is not proof of ownership.
        // Keep the existing admin-reviewed reset flow and leave sessions/password
        // unchanged until the administrator verifies the requester.
        [$conversation, $message] = DB::transaction(function () use ($user, $validated) {
            $conversation = Conversation::create([
                'user_id' => null,
                'guest_name' => $user->name,
                'guest_email' => $user->email,
                'last_message_at' => now(),
            ]);
            $message = Message::create([
                'conversation_id' => $conversation->id,
                'user_id' => null,
                'from_admin' => false,
                'body' => "Password reset request\nEmail: {$user->email}\nPhone: {$validated['phone']}\n"
                    . "Matched account ID: {$user->id}\nEmail and phone match the registered account. "
                    . 'Verify ownership before resetting this account to its default password.',
            ]);
            return [$conversation, $message];
        });
        Notifier::messageFromGuest($conversation, $message);

        return response()->json([
            'success' => true,
            'message' => 'Account matched. Your password reset request has been sent to the administrator for verification.',
        ], 201);
    }
}
