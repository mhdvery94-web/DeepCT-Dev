<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Services\StorageGuard;

/**
 * How much room is left, and how much of what is used will come back.
 *
 * Admin only. Free space on the results volume says how close the platform is
 * to refusing uploads, and the breakdown says whether that is a problem that
 * solves itself: prediction output is reclaimed 24 hours after each job, while
 * training datasets are reclaimed by nobody at all.
 */
class StorageController extends Controller
{
    public function show(StorageGuard $guard)
    {
        return response()->json([
            'success' => true,
            'data' => $guard->report(),
        ]);
    }
}
