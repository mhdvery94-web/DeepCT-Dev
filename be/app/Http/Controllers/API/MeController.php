<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\UserActivity;
use Illuminate\Http\Request;

/**
 * Self-service endpoints for the signed-in user.
 *
 * Everything under `/admin` requires the admin role, which left an ordinary
 * researcher with nothing but `GET /user`. These routes give the user
 * dashboard its own data without widening admin scope: every query here is
 * hard-scoped to `$request->user()`, and the model registry is exposed only as
 * an availability count, never as endpoint URLs.
 */
class MeController extends Controller
{
    /**
     * GET /api/me/activities
     *
     * The caller's own audit trail, newest first.
     */
    public function activities(Request $request)
    {
        $perPage = (int) $request->input('per_page', 20);
        // Keep a lid on how much a single call can pull.
        $perPage = max(1, min($perPage, 100));

        $query = UserActivity::where('user_id', $request->user()->id);

        if ($type = $request->input('type')) {
            $query->where('activity_type', $type);
        }

        $activities = $query->orderByDesc('created_at')->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $activities->items(),
            'pagination' => [
                'total' => $activities->total(),
                'per_page' => $activities->perPage(),
                'current_page' => $activities->currentPage(),
                'last_page' => $activities->lastPage(),
                'from' => $activities->firstItem(),
                'to' => $activities->lastItem(),
            ],
        ]);
    }

    /**
     * GET /api/me/stats
     *
     * Counters for the user dashboard. `analyses` stays at zero until the
     * FASE 3 prediction pipeline starts writing `analysis_records`; the shape
     * is already correct so the UI will not need changing then.
     */
    public function stats(Request $request)
    {
        $userId = $request->user()->id;

        $analysesByStatus = AnalysisRecord::where('user_id', $userId)
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        return response()->json([
            'success' => true,
            'data' => [
                'activities_total' => UserActivity::where('user_id', $userId)->count(),
                'activities_today' => UserActivity::where('user_id', $userId)
                    ->whereDate('created_at', now()->toDateString())
                    ->count(),

                'analyses_total' => (int) $analysesByStatus->sum(),
                'analyses_by_status' => [
                    'pending' => (int) $analysesByStatus->get('pending', 0),
                    'processing' => (int) $analysesByStatus->get('processing', 0),
                    'completed' => (int) $analysesByStatus->get('completed', 0),
                    'failed' => (int) $analysesByStatus->get('failed', 0),
                ],

                // Whether a prediction could run right now. Deliberately just a
                // count -- endpoint URLs stay admin-only.
                'models_online' => Model::where('is_active', true)
                    ->where('status', 'online')
                    ->count(),
                'models_total' => Model::where('is_active', true)->count(),
            ],
        ]);
    }
}
