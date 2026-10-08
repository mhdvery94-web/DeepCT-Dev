<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Services\StorageGuard;
use App\Models\AnalysisRecord;
use App\Models\UserActivity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * How much room is left, and how much of what is used will come back.
 *
 * Admin only. Free space on the results volume says how close the platform is
 * to refusing uploads, and the breakdown says whether that is a problem that
 * solves itself: prediction output is reclaimed
 * by their retention commands. Explicit cleanup is restricted to finished work.
 */
class StorageController extends Controller
{
    public function show(StorageGuard $guard)
    {
        $candidates = AnalysisRecord::with('user:id,name')
            ->whereIn('status', ['completed', 'failed'])
            ->whereNull('files_deleted_at')->orderBy('created_at')->limit(100)->get()
            ->filter(fn ($record) => $this->safeDirectory($record) !== null)
            ->map(fn ($record) => [
                'id' => $record->id, 'job_id' => $record->job_id,
                'file_name' => $record->file_name, 'owner' => $record->user?->name,
                'status' => $record->status, 'expires_at' => $record->expires_at?->toIso8601String(),
                'bytes' => $guard->bytesUnder($record->storageDirectory()),
            ])->values();

        return response()->json([
            'success' => true,
            'data' => $guard->report() + ['cleanup_candidates' => $candidates],
        ]);
    }

    /** Reuse retention rules, including the guards against active work. */
    public function cleanup(Request $request, StorageGuard $guard)
    {
        abort_unless($guard->isMounted(), 409, 'Application storage is not mounted.');
        $predictionStatus = Artisan::call('predictions:cleanup');
        $this->record($request, ['mode' => 'retention', 'prediction_status' => $predictionStatus]);

        return response()->json([
            'success' => $predictionStatus === 0,
            'message' => $predictionStatus === 0 ? 'Expired application files cleaned.' : 'Cleanup was incomplete. Refresh storage and check the application log.',
            'data' => $guard->report(),
        ], $predictionStatus === 0 ? 200 : 500);
    }

    /** Only files of a finished prediction. Its record and evidence survive. */
    public function cleanupPrediction(Request $request, StorageGuard $guard, $id)
    {
        abort_unless($guard->isMounted(), 409, 'Application storage is not mounted.');
        return DB::transaction(function () use ($request, $guard, $id) {
            $record = AnalysisRecord::lockForUpdate()->findOrFail($id);
            abort_unless(in_array($record->status, ['completed', 'failed'], true), 409, 'Active or unstarted predictions cannot be cleaned.');
            $directory = $this->safeDirectory($record);
            abort_if($directory === null, 409, 'Invalid application storage directory.');
            $bytes = $record->files_deleted_at === null ? $guard->bytesUnder($directory) : 0;
            if ($record->files_deleted_at === null) {
                abort_unless(Storage::deleteDirectory($directory), 500, 'Unable to remove application files.');
                $record->update(['files_deleted_at' => now()]);
            }
            $this->record($request, ['prediction_id' => $record->id, 'freed_bytes' => $bytes]);
            return response()->json(['success' => true, 'message' => 'Prediction files removed. Research history and evidence are preserved.', 'data' => ['freed_bytes' => $bytes]]);
        });
    }

    private function safeDirectory(AnalysisRecord $record): ?string
    {
        if (!preg_match('/^[a-zA-Z0-9-]+$/D', (string) $record->job_id)) return null;
        $directory = $record->storageDirectory();
        $root = realpath(Storage::path(''));
        $path = realpath(Storage::path($directory));
        // Reject symlinks pointing outside the application disk.
        if ($path !== false && ($root === false || !str_starts_with($path, $root . DIRECTORY_SEPARATOR))) return null;
        return $directory;
    }

    private function record(Request $request, array $metadata): void
    {
        UserActivity::create([
            'user_id' => $request->user()->id, 'activity_type' => 'storage_cleanup',
            'description' => 'Cleaned application storage', 'metadata' => $metadata,
            'ip_address' => $request->ip(), 'user_agent' => $request->userAgent(),
        ]);
    }
}
