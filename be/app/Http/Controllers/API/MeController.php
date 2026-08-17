<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\UserActivity;
use App\Services\ModelHealthChecker;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

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
     * GET /api/me/models
     *
     * Models a researcher may submit work to. Deliberately narrow: id, name,
     * version and reachability only. `endpoint_url` stays admin-only, since
     * knowing it would let anyone bypass the platform and hit the GPU worker
     * directly.
     */
    public function models()
    {
        $models = Model::inference()
            ->where('is_active', true)
            ->orderByDesc('status') // online sorts before offline
            ->orderBy('name')
            ->get([
                'id', 'name', 'version', 'status', 'description', 'accuracy',
                'last_health_check', 'health_check_error',
            ]);

        return response()->json([
            'success' => true,
            'data' => $models->map(fn($m) => [
                'id' => $m->id,
                'name' => $m->name,
                'version' => $m->version,
                'status' => $m->status,
                'description' => $m->description,
                'accuracy' => $m->accuracy,
                'is_available' => $m->status === 'online',
                // The client polls this every 10 seconds and shows how fresh
                // the answer is. Without the timestamp a stale scheduler looks
                // identical to a healthy model.
                'last_health_check' => $m->last_health_check?->toIso8601String(),
                // Why it is down, in the worker's own words — "Tunnel is not
                // running (ERR_NGROK_3200)" tells a researcher to go restart
                // Kaggle, where "offline" alone does not.
                'health_check_error' => $m->status === 'online'
                    ? null
                    : $m->health_check_error,
            ]),
        ]);
    }

    /**
     * How fresh a status has to be for the refresh button to accept it as is.
     *
     * The scheduler probes every minute now, and a button pressed twice in a
     * row should not probe twice: the second press is a person waiting, not new
     * information.
     */
    private const FRESH_SECONDS = 10;

    /**
     * POST /api/me/models/refresh
     *
     * Probe the endpoints, then answer exactly as {@see models()} does.
     *
     * The scheduled check runs once a minute, which is right for a status light
     * nobody is watching and wrong for the moment someone is about to spend
     * twenty minutes uploading. This is the one place an ordinary user causes an
     * outbound request, so it is fenced three ways: the route is throttled, a
     * lock stops concurrent presses from fanning out into duplicate probes, and
     * a status younger than [FRESH_SECONDS] is returned untouched.
     *
     * Worst case it holds a worker for one probe timeout — the probes themselves
     * run as a pool, so several models cost the slowest one rather than all.
     */
    public function refreshModels(ModelHealthChecker $checker)
    {
        $models = Model::where('is_active', true)
            ->whereNotNull('endpoint_url')
            ->get();

        $stale = $models->filter(
            fn (Model $model) => $model->last_health_check === null
                || $model->last_health_check->lt(now()->subSeconds(self::FRESH_SECONDS))
        );

        if ($stale->isNotEmpty()) {
            // Non-blocking: a press that arrives while another probe is in
            // flight reads that probe's result a moment later instead of
            // starting a second one.
            $lock = Cache::lock('models:probe', ModelHealthChecker::TIMEOUT_SECONDS + 2);

            if ($lock->get()) {
                try {
                    $checker->checkMany($stale);
                } finally {
                    $lock->release();
                }
            }
        }

        return $this->models();
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
