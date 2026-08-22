<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\UserActivity;
use Illuminate\Http\Request;

class UserActivityController extends Controller
{
    /**
     * Display a listing of user activities with filters
     */
    public function index(Request $request)
    {
        $perPage = $request->input('per_page', 20);
        $userId = $request->input('user_id');
        $type = $request->input('type');
        $dateFrom = $request->input('date_from');
        $dateTo = $request->input('date_to');

        $query = UserActivity::with('user:id,name,email,avatar_path');

        // Filter by user
        if ($userId) {
            $query->where('user_id', $userId);
        }

        // Filter by activity type
        if ($type) {
            $query->where('activity_type', $type);
        }

        // Filter by date range
        if ($dateFrom) {
            $query->whereDate('created_at', '>=', $dateFrom);
        }
        if ($dateTo) {
            $query->whereDate('created_at', '<=', $dateTo);
        }

        $activities = $query->orderBy('created_at', 'desc')->paginate($perPage);

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
     * Get activities for a specific user
     */
    public function userActivities(Request $request, $userId)
    {
        $perPage = $request->input('per_page', 20);
        $type = $request->input('type');

        $query = UserActivity::where('user_id', $userId)
            ->with('user:id,name,email,avatar_path');

        // Filter by activity type
        if ($type) {
            $query->where('activity_type', $type);
        }

        $activities = $query->orderBy('created_at', 'desc')->paginate($perPage);

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
     * Get available activity types
     */
    public function getTypes()
    {
        $types = UserActivity::select('activity_type')
            ->distinct()
            ->orderBy('activity_type')
            ->pluck('activity_type');

        return response()->json([
            'success' => true,
            'data' => $types,
        ]);
    }
}
