<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessDeepLearningImage;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\UserActivity;
use App\Services\IntakeException;
use App\Services\PredictionIntake;
use App\Services\QueueHealth;
use App\Services\TiffPreview;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use ZipArchive;
use Exception;

class AnalysisController extends Controller
{
    public function __construct(private readonly PredictionIntake $intake) {}

    /**
     * Upload ZIP file dan mulai prediksi
     * POST /api/predictions
     */
    public function store(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimes:zip|max:2097152', // Max 2GB
            'model_id' => 'required|exists:models,id',
        ]);

        $user = $request->user();
        $model = Model::findOrFail($request->model_id);
        $uploaded = $request->file('file');

        try {
            // Extraction, validation, record creation and dispatch are shared
            // with the chunked upload flow so the two cannot drift apart.
            $prediction = $this->intake->fromZip(
                $user,
                $model,
                $uploaded->getRealPath(),
                $request->ip(),
                $request->userAgent(),
                $uploaded->getClientOriginalName()
            );
        } catch (IntakeException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], $e->status());
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to process upload: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Prediction started. Processing will begin shortly.',
            'data' => [
                'id' => $prediction->id,
                'job_id' => $prediction->job_id,
                'status' => 'pending',
                'input_files_count' => $prediction->input_files_count,
                'queue_position' => $this->getQueuePosition($prediction),
                'estimated_wait_minutes' => $this->estimateWaitTime($prediction),
                'expires_at' => $prediction->expires_at->toIso8601String(),
                'created_at' => $prediction->created_at->toIso8601String(),
            ],
        ], 201);
    }

    /**
     * Get queue position for a prediction
     */
    private function getQueuePosition($prediction)
    {
        return AnalysisRecord::where('status', 'pending')
            ->where('created_at', '<', $prediction->created_at)
            ->count() + 1;
    }

    /**
     * Estimate wait time in minutes
     */
    private function estimateWaitTime($prediction)
    {
        $queuePosition = $this->getQueuePosition($prediction);
        $avgProcessingTimeMinutes = 5; // Assumption: 5 minutes per job
        return $queuePosition * $avgProcessingTimeMinutes;
    }

    /**
     * Get list of user's predictions
     * GET /api/predictions
     */
    public function index(Request $request)
    {
        $user = auth()->user();
        $perPage = $request->input('per_page', 10);
        $status = $request->input('status'); // Filter by status

        $query = AnalysisRecord::where('user_id', $user->id)
            ->with('model:id,name,version')
            ->orderBy('created_at', 'desc');

        if ($status) {
            $query->where('status', $status);
        }

        $predictions = $query->paginate($perPage);

        // Inspected once. `message()` used to re-inspect, so this endpoint ran
        // four queries against `jobs` for two questions.
        $queueHealth = app(QueueHealth::class);
        $queueState = $queueHealth->inspect();

        return response()->json([
            'success' => true,
            'data' => $predictions->items(),
            'pagination' => [
                'current_page' => $predictions->currentPage(),
                'per_page' => $predictions->perPage(),
                'total' => $predictions->total(),
                'last_page' => $predictions->lastPage(),
            ],
            // Whether anything is actually consuming the queue. A job sitting
            // at `pending` for ever with no error anywhere is the most
            // confusing state this application has, and it is invisible unless
            // we say so — see App\Services\QueueHealth.
            'meta' => $queueState + [
                'queue_message' => $queueHealth->message($queueState),
            ],
        ]);
    }

    /**
     * Get prediction detail and status
     * GET /api/predictions/{id}
     */
    public function show($id)
    {
        $user = auth()->user();
        
        $prediction = AnalysisRecord::with('model:id,name,version')
            ->where('id', $id)
            ->where('user_id', $user->id)
            ->firstOrFail();

        $data = [
            'id' => $prediction->id,
            'job_id' => $prediction->job_id,
            'user_id' => $prediction->user_id,
            'status' => $prediction->status,
            'input_files_count' => $prediction->input_files_count,
            'output_files_count' => $prediction->output_files_count,
            'processing_time' => $prediction->processing_time_seconds ? 
                round($prediction->processing_time_seconds, 2) . ' seconds' : null,
            'model' => $prediction->model ? [
                'id' => $prediction->model->id,
                'name' => $prediction->model->name,
                'version' => $prediction->model->version,
            ] : null,
            'created_at' => $prediction->created_at->toIso8601String(),
            'expires_at' => $prediction->expires_at ? $prediction->expires_at->toIso8601String() : null,
            'files_deleted_at' => $prediction->files_deleted_at ? $prediction->files_deleted_at->toIso8601String() : null,
        ];

        // Add error message if failed
        if ($prediction->status === 'failed' && $prediction->error_message) {
            $data['error_message'] = $prediction->error_message;
        }

        // Add queue info if pending
        if ($prediction->status === 'pending') {
            $data['queue_position'] = $this->getQueuePosition($prediction);
            $data['estimated_wait_minutes'] = $this->estimateWaitTime($prediction);

            // "Queued" with no worker behind it looks exactly like "queued"
            // with one. Say which it is rather than leaving someone watching
            // a clock icon that will never change.
            $data['queue_stalled_message'] = app(QueueHealth::class)->message();
        }

        // Add completed_at if completed
        if ($prediction->status === 'completed') {
            $data['completed_at'] = $prediction->updated_at->toIso8601String();
            
            // Check if files still available
            if ($prediction->files_deleted_at) {
                $data['files_available'] = false;
                $data['message'] = 'Files have been deleted after expiration';
            } else {
                $data['files_available'] = true;
            }
        }

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    /**
     * GET /api/predictions/{id}/frames
     *
     * What is on disk for this job, so the client can build a gallery without
     * downloading a multi-megabyte archive first.
     */
    public function frames(Request $request, $id)
    {
        $prediction = $this->findOwned($request, $id);

        if (!$prediction->hasFiles()) {
            return response()->json([
                'success' => false,
                'message' => 'Files have expired and been deleted',
            ], 410);
        }

        $describe = function (string $folder, string $kind) {
            return collect(Storage::files($folder))
                ->map(fn($path) => [
                    'name' => basename($path),
                    'kind' => $kind,
                    'size' => Storage::size($path),
                ])
                ->sortBy('name')
                ->values();
        };

        $frames = $describe($prediction->input_folder, 'input')
            ->concat($describe($prediction->output_folder, 'output'));

        return response()->json([
            'success' => true,
            'data' => $frames->values(),
        ]);
    }

    /**
     * GET /api/predictions/{id}/frames/{name}/preview
     *
     * A PNG rendering of one frame. Browsers and Flutter cannot display the
     * 16-bit TIFFs the model produces, so they are converted here and cached
     * beside the job — which means `predictions:cleanup` disposes of the
     * previews along with everything else.
     */
    public function framePreview(Request $request, $id, string $name)
    {
        $prediction = $this->findOwned($request, $id);

        if (!$prediction->hasFiles()) {
            return response()->json([
                'success' => false,
                'message' => 'Files have expired and been deleted',
            ], 410);
        }

        // basename() keeps a crafted name from escaping the job's folders.
        $name = basename($name);
        $size = (int) $request->input('size', 512);
        $size = max(64, min($size, 2048));

        $source = collect([$prediction->output_folder, $prediction->input_folder])
            ->map(fn($folder) => "{$folder}/{$name}")
            ->first(fn($path) => Storage::exists($path));

        if ($source === null) {
            return response()->json([
                'success' => false,
                'message' => 'Frame not found',
            ], 404);
        }

        $cachePath = "{$prediction->storageDirectory()}/preview/{$size}_{$name}.png";

        if (!Storage::exists($cachePath)) {
            try {
                $png = app(TiffPreview::class)->toPng(Storage::get($source), $size);
            } catch (Exception $e) {
                return response()->json([
                    'success' => false,
                    'message' => 'Could not render this frame: ' . $e->getMessage(),
                ], 422);
            }

            Storage::put($cachePath, $png);
        }

        return response(Storage::get($cachePath), 200, [
            'Content-Type' => 'image/png',
            // Frames never change once written, and the whole job disappears
            // after 24 hours anyway.
            'Cache-Control' => 'private, max-age=86400',
        ]);
    }

    /** Fetch a record that belongs to the caller, or 404. */
    /**
     * POST /api/predictions/{id}/start — queue an upload that is waiting.
     *
     * Upload and analysis are separate so a researcher can look at the frames
     * before spending a GPU slot on them. This is the second half.
     */
    public function start(Request $request, $id)
    {
        // 404 rather than 403 for someone else's record: whether it exists is
        // not their business either.
        $prediction = $this->findOwned($request, $id);

        if (!$prediction->hasFiles()) {
            return response()->json([
                'success' => false,
                'message' => 'Files have expired and been deleted',
            ], 410);
        }

        if ($prediction->status !== 'uploaded') {
            // A double tap on a phone reaches here. Two workers on one job
            // would write over the same output folder.
            return response()->json([
                'success' => false,
                'message' => 'This analysis has already been started.',
            ], 409);
        }

        $prediction->update(['status' => 'pending']);

        ProcessDeepLearningImage::dispatch($prediction);

        UserActivity::create([
            'user_id' => $request->user()->id,
            'model_id' => $prediction->model_id,
            'activity_type' => 'prediction',
            'description' => "Started analysis of {$prediction->input_files_count} frame(s)",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Analysis queued.',
            'data' => [
                'id' => $prediction->id,
                'status' => $prediction->status,
                'queue_position' => AnalysisRecord::where('status', 'pending')
                    ->where('created_at', '<', $prediction->created_at)
                    ->count() + 1,
            ],
        ]);
    }

    private function findOwned(Request $request, $id): AnalysisRecord
    {
        return AnalysisRecord::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();
    }

    /**
     * Download results only (predicted files)
     * GET /api/predictions/{id}/download/results
     */
    public function downloadResults($id)
    {
        return $this->downloadZip($id, 'results');
    }

    /**
     * Download complete sequence (inputs + outputs organized)
     * GET /api/predictions/{id}/download/complete
     */
    public function downloadComplete($id)
    {
        return $this->downloadZip($id, 'complete');
    }

    /**
     * Create and stream ZIP download
     */
    private function downloadZip($id, $type = 'results')
    {
        $user = auth()->user();
        
        $prediction = AnalysisRecord::where('id', $id)
            ->where('user_id', $user->id)
            ->firstOrFail();

        // Check if completed
        if ($prediction->status !== 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'Prediction is not completed yet',
            ], 400);
        }

        // Check if files expired
        if ($prediction->files_deleted_at) {
            return response()->json([
                'success' => false,
                'message' => 'Files have expired and been deleted',
            ], 410); // 410 Gone
        }

        try {
            // Create ZIP on-demand
            $zipPath = $this->createZipOnDemand($prediction, $type);
            $zipName = $type === 'results' ? 
                "results_{$prediction->job_id}.zip" : 
                "complete_{$prediction->job_id}.zip";

            // Calculate MD5
            $md5 = md5_file(Storage::path($zipPath));
            $size = Storage::size($zipPath);

            // Log activity
            UserActivity::create([
                'user_id' => $user->id,
                'activity_type' => 'download',
                'description' => "Downloaded {$type} for job {$prediction->job_id}",
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent(),
                'metadata' => [
                    'job_id' => $prediction->job_id,
                    'download_type' => $type,
                    'file_size' => $size,
                ],
            ]);

            $absolutePath = Storage::path($zipPath);

            // Delete the on-demand ZIP once the response has gone out.
            //
            // `deleteFileAfterSend(true)` is NOT enough here: Symfony performs
            // that unlink inside BinaryFileResponse::sendContent(), which
            // Octane never calls -- it converts the response to PSR-7 for
            // RoadRunner instead. Relying on it leaks a full-size ZIP per
            // download. A terminating callback does run under Octane.
            app()->terminating(function () use ($absolutePath) {
                if (is_file($absolutePath)) {
                    @unlink($absolutePath);
                }
            });

            // BinaryFileResponse rather than streamDownload: it honours HTTP
            // Range requests, which is what lets an interrupted download
            // resume.
            return response()->download(
                $absolutePath,
                $zipName,
                [
                    'Content-Type' => 'application/zip',
                    'X-Checksum-MD5' => $md5,
                    'Content-MD5' => base64_encode(hex2bin($md5)),
                ]
            );

        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to create download: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Create ZIP file on-demand
     */
    private function createZipOnDemand($prediction, $type)
    {
        $zip = new ZipArchive();
        $zipFilename = "temp/downloads/{$prediction->user_id}/{$type}_{$prediction->job_id}.zip";
        $zipPath = Storage::path($zipFilename);

        // Create directory if not exists
        $directory = dirname($zipPath);
        if (!file_exists($directory)) {
            mkdir($directory, 0755, true);
        }

        if ($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
            throw new Exception('Failed to create ZIP file');
        }

        if ($type === 'results') {
            // Add only output files
            $outputFiles = Storage::files($prediction->output_folder);
            foreach ($outputFiles as $file) {
                $zip->addFile(Storage::path($file), basename($file));
            }
        } else {
            // Add organized structure
            // input/ folder
            $inputFiles = Storage::files($prediction->input_folder);
            foreach ($inputFiles as $file) {
                $zip->addFile(Storage::path($file), 'input/' . basename($file));
            }

            // output/ folder
            $outputFiles = Storage::files($prediction->output_folder);
            foreach ($outputFiles as $file) {
                $zip->addFile(Storage::path($file), 'output/' . basename($file));
            }

            // metadata.json
            $metadata = [
                'job_id' => $prediction->job_id,
                'created_at' => $prediction->created_at->toIso8601String(),
                'completed_at' => $prediction->updated_at->toIso8601String(),
                'processing_time_seconds' => $prediction->processing_time_seconds,
                'model' => [
                    'name' => $prediction->model->name,
                    'version' => $prediction->model->version,
                ],
                'input_files_count' => $prediction->input_files_count,
                'output_files_count' => $prediction->output_files_count,
            ];
            $zip->addFromString('metadata.json', json_encode($metadata, JSON_PRETTY_PRINT));
        }

        $zip->close();
        return $zipFilename;
    }

    /**
     * Delete prediction and its files
     * DELETE /api/predictions/{id}
     */
    public function destroy($id)
    {
        $user = auth()->user();
        
        $prediction = AnalysisRecord::where('id', $id)
            ->where('user_id', $user->id)
            ->firstOrFail();

        try {
            // Delete physical files if not already deleted
            if (!$prediction->files_deleted_at) {
                Storage::deleteDirectory("predictions/{$prediction->user_id}/{$prediction->job_id}");
            }

            // Delete database record
            $prediction->delete();

            // Log activity
            UserActivity::create([
                'user_id' => $user->id,
                'activity_type' => 'delete_prediction',
                'description' => "Deleted prediction {$prediction->job_id}",
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Prediction deleted successfully',
            ]);

        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to delete prediction: ' . $e->getMessage(),
            ], 500);
        }
    }
}