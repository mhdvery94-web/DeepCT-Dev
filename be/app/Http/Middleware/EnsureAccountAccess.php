<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Enforce account state on every authenticated API request, not only at login. */
class EnsureAccountAccess
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user?->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Your account has been deactivated. Please contact an administrator.',
            ], 403);
        }

        if ($user->must_change_password && !$request->routeIs(
            'api.user',
            'api.me.password',
            'api.logout'
        )) {
            return response()->json([
                'success' => false,
                'message' => 'Change your issued password before using the platform.',
            ], 403);
        }

        return $next($request);
    }
}
