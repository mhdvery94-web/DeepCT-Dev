<?php

namespace App\Http\Controllers;

/**
 * GET /api/health — is the API answering at all?
 *
 * The one endpoint that needs no token, so it is what a client, a tunnel check
 * or a deployment script probes first. `docs/OPERATIONS.md` documents
 * `curl <API_BASE_URL>/health` as the first thing to try when the app cannot
 * reach the server.
 *
 * It is a controller rather than a closure for one unglamorous reason:
 * `php artisan route:cache` refuses to serialise closure routes, and without
 * that cache every console command — including the health check that runs six
 * times a minute — recompiles the whole route table before it can start.
 */
class HealthController extends Controller
{
    public function __invoke()
    {
        return response()->json([
            'success' => true,
            'message' => 'API is running',
            'timestamp' => now(),
        ]);
    }
}
