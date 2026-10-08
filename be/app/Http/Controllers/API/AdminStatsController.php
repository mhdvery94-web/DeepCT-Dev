<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\AccessRequest;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use App\Models\UserActivity;
use App\Services\StorageGuard;

class AdminStatsController extends Controller
{
    public function show(StorageGuard $storage)
    {
        return response()->json(['success' => true, 'data' => [
            'activities_total' => UserActivity::count(),
            'activities_today' => UserActivity::whereDate('created_at', today())->count(),
            'analyses_total' => AnalysisRecord::count(),
            'analyses_by_status' => AnalysisRecord::selectRaw('status, COUNT(*) as count')->groupBy('status')->pluck('count', 'status')->map(fn ($count) => (int) $count),
            'models_online' => Model::inference()->where('is_active', true)->whereIn('status', ['online', 'trouble'])->count(),
            'models_total' => Model::inference()->count(),
            'users_total' => User::count(),
            'pending_requests' => AccessRequest::where('status', 'pending')->count(),
            'free_bytes' => $storage->freeBytes(),
        ]]);
    }
}
