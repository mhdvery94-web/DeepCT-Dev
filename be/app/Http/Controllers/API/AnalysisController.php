<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\UserActivity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use App\Jobs\ProcessDeepLearningImage;
use ZipArchive;
use Exception;

class AnalysisController extends Controller
{
    /**
     * Upload ZIP file dan mulai prediksi
     * POST /api/predictions
     */
    public function store(Request $request)
    {
        // Validation
        $request->validate([
            'file' => 'required|file|mimes:zip|max:2097152', // Max 2GB
            'model_id' => 'required|exists:models,id',
        ]);

        $user = auth()->user();
        $jobId = (string) Str::uuid();

        try {
            // Check if model is active and online
            $model = Model::findOrFail($request->model_id);
            if (!$model->is_active) {
                return response()->json([
                    'success' => false,
                    'message' => 'Selected model is not active',
                ], 400);
            }

            if ($model->status === 'offline') {
                return response()->json([
                    'success' => false,
                    'message' => 'Selected model is currently offline',
                ], 503);
            }

            // Save uploaded ZIP temporarily
            $uploadedFile = $request->file('file');
            $tempZipPath = $uploadedFile->storeAs(
                "temp/uploads/{$user->id}",
                "{$jobId}.zip",
                'local'
            );

            // Extract ZIP
            $inputFolder = "predictions/{$user->id}/{$jobId}/input";
            $filesExtracted = $this->extractZip($tempZipPath, $inputFolder);

            if ($filesExtracted === 0) {
                // Clean up
                Storage::delete($tempZipPath);
                return response()->json([
                    'success' => false,
                    'message' => 'ZIP file is empty or contains no valid files',
                ], 422);
            }

            // Validate extracted files
            $validationError = $this->validateTifFiles($inputFolder);
            if ($validationError) {
                // Clean up
                Storage::delete($tempZipPath);
                Storage::deleteDirectory($inputFolder);
                return response()->json([
                    'success' => false,
                    'message' => $validationError,
                ], 422);
            }

            // Create analysis record
            $prediction = AnalysisRecord::create([
                'user_id' => $user->id,
                'job_id' => $jobId,
                'model_id' => $model->id,
                'input_folder' => $inputFolder,
                'output_folder' => "predictions/{$user->id}/{$jobId}/output",
                'status' => 'pending',
                'input_files_count' => $filesExtracted,
                'expires_at' => now()->addHours(24),
            ]);

            // Delete temp ZIP
            Storage::delete($tempZipPath);

            // Dispatch job to queue
            ProcessDeepLearningImage::dispatch($prediction);

            // Log activity
            UserActivity::create([
                'user_id' => $user->id,
                'model_id' => $model->id,
                'activity_type' => 'prediction',
                'description' => "Started prediction with {$filesExtracted} input files",
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'metadata' => [
                    'job_id' => $jobId,
                    'model_name' => $model->name,
                    'file_count' => $filesExtracted,
                ],
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Prediction started. Processing will begin shortly.',
                'data' => [
                    'id' => $prediction->id,
                    'job_id' => $jobId,
                    'status' => 'pending',
                    'input_files_count' => $filesExtracted,
                    'queue_position' => $this->getQueuePosition($prediction),
                    'estimated_wait_minutes' => $this->estimateWaitTime($prediction),
                    'expires_at' => $prediction->expires_at->toIso8601String(),
                    'created_at' => $prediction->created_at->toIso8601String(),
                ],
            ], 201);

        } catch (Exception $e) {
            // Clean up on error
            if (isset($tempZipPath)) Storage::delete($tempZipPath);
            if (isset($inputFolder)) Storage::deleteDirectory($inputFolder);

            return response()->json([
                'success' => false,
                'message' => 'Failed to process upload: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Extract ZIP file to storage
     */
    private function extractZip($zipPath, $destinationFolder)
    {
        $zip = new ZipArchive();
        $absoluteZipPath = Storage::path($zipPath);
        $absoluteDestination = Storage::path($destinationFolder);

        // Create destination directory
        if (!Storage::exists($destinationFolder)) {
            Storage::makeDirectory($destinationFolder);
        }

        if ($zip->open($absoluteZipPath) === true) {
            $filesExtracted = 0;

            for ($i = 0; $i < $zip->numFiles; $i++) {
                $filename = $zip->getNameIndex($i);
                
                // Skip directories and hidden files
                if (substr($filename, -1) === '/' || strpos($filename, '__MACOSX') !== false) {
                    continue;
                }

                // Extract only .tif files
                if (strtolower(pathinfo($filename, PATHINFO_EXTENSION)) === 'tif') {
                    $zip->extractTo($absoluteDestination, $filename);
                    $filesExtracted++;
                }
            }

            $zip->close();
            return $filesExtracted;
        }

        throw new Exception('Failed to open ZIP file');
    }

    /**
     * Validate extracted TIF files
     */
    private function validateTifFiles($folder)
    {
        $files = Storage::files($folder);

        if (count($files) < 2) {
            return 'At least 2 TIF files are required for interpolation';
        }

        // Check if all files are .tif
        foreach ($files as $file) {
            $extension = strtolower(pathinfo($file, PATHINFO_EXTENSION));
            if ($extension !== 'tif' && $extension !== 'tiff') {
                return 'All files must be .tif or .tiff format';
            }

            // Check file size (max 50MB per file)
            $fileSize = Storage::size($file);
            if ($fileSize > 50 * 1024 * 1024) {
                return 'Individual file size must not exceed 50MB';
            }
        }

        // Check naming convention (should contain numbers)
        $hasNumbers = false;
        foreach ($files as $file) {
            $basename = pathinfo($file, PATHINFO_FILENAME);
            if (preg_match('/\d+/', $basename)) {
                $hasNumbers = true;
                break;
            }
        }

        if (!$hasNumbers) {
            return 'Files should contain frame numbers in their names (e.g., frame_001.tif, image_003.tif)';
        }

        return null; // No errors
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

        return response()->json([
            'success' => true,
            'data' => $predictions->items(),
            'pagination' => [
                'current_page' => $predictions->currentPage(),
                'per_page' => $predictions->perPage(),
                'total' => $predictions->total(),
                'last_page' => $predictions->lastPage(),
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