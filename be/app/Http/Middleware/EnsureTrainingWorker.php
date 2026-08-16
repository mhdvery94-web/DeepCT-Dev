<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Authenticates a GPU training worker.
 *
 * Deliberately **not** a Sanctum user token. A worker is a machine, not a
 * person: its credential lives in a notebook that may be shared or re-run for
 * weeks, it needs no account, and it must never be able to reach anything
 * outside the training endpoints. A single shared secret in the environment is
 * the right size for that, and rotating it is one `.env` edit.
 *
 * Set `TRAINING_WORKER_TOKEN` on the server and paste the same value into the
 * notebook. With no token configured every worker route refuses, so a
 * half-configured deployment fails closed rather than open.
 */
class EnsureTrainingWorker
{
    public function handle(Request $request, Closure $next): Response
    {
        $expected = config('training.worker_token');

        if (empty($expected)) {
            return response()->json([
                'success' => false,
                'message' => 'Training workers are not configured on this server.',
            ], 503);
        }

        $presented = $request->bearerToken() ?? $request->header('X-Worker-Token');

        // Constant-time: a token compared with == leaks its prefix through
        // timing, and this one guards write access to model weights.
        if (!is_string($presented) || !hash_equals($expected, $presented)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid worker token.',
            ], 401);
        }

        return $next($request);
    }
}
