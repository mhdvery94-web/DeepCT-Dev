<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessDeepLearningImage;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\UserActivity;
use App\Services\IntakeException;
use App\Services\PredictionIntake;
use App\Services\QueueBoard;
use App\Services\QueueHealth;
use App\Services\ResultEvidence;
use App\Services\ResultManifest;
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
                // The record's own status, not the literal `pending` that
                // stood here. Intake lands a run as `uploaded` and waits for
                // START, so this response announced a queued job that was not
                // queued — and then quoted it a position in a line it was not
                // standing in. Both now come from the record and the board.
                'status' => $prediction->status,
                'input_files_count' => $prediction->input_files_count,
                'queue_position' => $this->getQueuePosition($prediction),
                'estimated_wait_minutes' => $this->estimateWaitTime($prediction),
                'expires_at' => $prediction->expires_at->toIso8601String(),
                'created_at' => $prediction->created_at->toIso8601String(),
            ],
        ], 201);
    }

    /**
     * Where this record sits in the line, or null if it is not in one.
     *
     * Read from [QueueBoard], which is also what the administrator's queue
     * screen and the history list read. This method used to count the rows
     * with an earlier `created_at`, which is a second definition of the same
     * ordering — equal to the board's until two records share a timestamp,
     * and then quietly not.
     */
    private function getQueuePosition(AnalysisRecord $prediction): ?int
    {
        return app(QueueBoard::class)->positionOf($prediction);
    }

    /**
     * Estimate wait time in minutes, from how long this platform's jobs
     * actually take rather than from a guess.
     *
     * The constant used to be five minutes per job, written before a single
     * run had been measured. Real runs on the current worker take between
     * fifty seconds and two and a half minutes, so the guess overstated the
     * wait roughly threefold — and an estimate that is always wrong in the
     * same direction teaches people to ignore it.
     *
     * Twenty jobs, because the number that matters is what the worker is
     * doing lately: a GPU that has been swapped, or a worker session that came
     * back slower, should show up here within a day rather than being averaged
     * away by months of history.
     */
    private function estimateWaitTime(AnalysisRecord $prediction): ?int
    {
        $place = $this->getQueuePosition($prediction);

        return $place === null ? null : $place * $this->minutesPerJob();
    }

    /**
     * Average of recent completed runs, with a floor and a cap.
     *
     * Lives in [QueueBoard] because the administrator's queue screen answers
     * the same question, and two implementations of "how long does a run take"
     * would disagree the first time either changed — surfacing as one person's
     * screen contradicting the other's.
     */
    private function minutesPerJob(): int
    {
        return app(QueueBoard::class)->minutesPerJob();
    }

    /**
     * Attach the queue position to every pending row on this page.
     *
     * It was computed on the detail endpoint only, so the history screen —
     * the one place a researcher actually watches a job wait — received
     * `queue_position: null` and drew nothing. The wait looked open-ended
     * because nothing on that screen ever said where in the line the job was.
     *
     * One query for the whole page rather than one per row: the positions of
     * every pending job are decided by a single ordering, so reading that
     * ordering once answers all of them.
     *
     * @param  array<int, AnalysisRecord>  $records
     * @return array<int, array<string, mixed>>
     */
    private function withQueuePositions(array $records): array
    {
        $pending = array_filter($records, fn ($r) => $r->status === 'pending');

        if ($pending === []) {
            return array_map(fn ($r) => $r->toArray(), $records);
        }

        // Everyone's jobs, not just this user's: a position that counted only
        // your own would say "1" while five other people were ahead of you.
        // The administrator's queue screen reads the same ordering from the
        // same place, so the two can never disagree.
        $board = app(QueueBoard::class);
        $positions = $board->positions();
        $perJob = $board->minutesPerJob();

        return array_map(function ($record) use ($positions, $perJob) {
            $row = $record->toArray();

            if ($record->status === 'pending' && isset($positions[$record->id])) {
                $row['queue_position'] = $positions[$record->id];
                $row['estimated_wait_minutes'] = $positions[$record->id] * $perJob;
            }

            return $row;
        }, $records);
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
            'data' => $this->withQueuePositions($predictions->items()),
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
            // The administrator gets the command to type; the researcher gets
            // the fact without it. Same condition, different reader — see
            // QueueHealth::researcherMessage().
            'meta' => $queueState + [
                'queue_message' => $user->role === 'admin'
                    ? $queueHealth->message($queueState)
                    : $queueHealth->researcherMessage($queueState),
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
            'file_name' => $prediction->file_name,
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

            // Which two frames each generated frame was drawn between, and how
            // many times the model had been fed its own output by then. Null
            // on records written before this was recorded, which is why every
            // reader has to treat it as optional.
            'frame_provenance' => $prediction->frame_provenance,

            // How the interpolation scored against a frame the archive already
            // held. Null when the upload offered no consecutive triplet to
            // hold one out from, which is an ordinary case rather than a
            // failure — readers must not treat its absence as an error.
            'validation' => $prediction->validation,
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
            $data['queue_stalled_message'] = $user->role === 'admin'
                ? app(QueueHealth::class)->message()
                : app(QueueHealth::class)->researcherMessage();
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

        // Every run on these same frames, this one included, with the one
        // number worth comparing them by. The registry has always been able to
        // hold several inference endpoints; this is what lets a researcher
        // find out which of them is better on their own data.
        $data['rerun_of_id'] = $prediction->rerun_of_id;
        $data['comparison'] = $this->comparisonFor($prediction);

        // Thumbnails that survive the retention window. Empty for jobs that
        // completed before this existed, and for jobs that produced nothing.
        $data['evidence'] = app(ResultEvidence::class)->listFor($prediction);

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    /**
     * The family of runs sharing one set of input frames.
     *
     * A re-run points at the job it was made from, so the family is that job
     * plus everything pointing at it. Ordered oldest first, because the first
     * one is the baseline the others are being weighed against.
     *
     * @return array<int, array<string, mixed>>
     */
    private function comparisonFor(AnalysisRecord $prediction): array
    {
        $rootId = $prediction->rerun_of_id ?? $prediction->id;

        $family = AnalysisRecord::with('model:id,name,version')
            ->where('user_id', $prediction->user_id)
            ->where(fn($q) => $q->where('id', $rootId)->orWhere('rerun_of_id', $rootId))
            ->orderBy('id')
            ->get();

        // One run alone is not a comparison, and a panel showing a single row
        // reads as though something failed to load.
        if ($family->count() < 2) {
            return [];
        }

        return $family->map(fn(AnalysisRecord $run) => [
            'id' => $run->id,
            'status' => $run->status,
            'is_current' => $run->id === $prediction->id,
            'model' => $run->model?->name,
            'model_version' => $run->model?->version,
            'output_files_count' => $run->output_files_count,
            'processing_time_seconds' => $run->processing_time_seconds,
            // Null where the archive offered no frame to hold out, which is
            // the case that makes two runs incomparable — and saying so is
            // more useful than printing a dash.
            'mae' => $run->validation['mae'] ?? null,
            'psnr' => $run->validation['psnr'] ?? null,
        ])->values()->all();
    }

    /**
     * GET /api/predictions/{id}/evidence/{name}
     *
     * One kept thumbnail, as a PNG.
     *
     * Deliberately **not** gated on `hasFiles()`. These outlive the frames
     * they were made from, and refusing them once the originals expire would
     * defeat the only reason they exist.
     */
    public function evidence(Request $request, $id, string $name)
    {
        $prediction = $this->findOwned($request, $id);

        // The name comes from a URL. Anything with a separator in it is not a
        // filename, whatever else it might be.
        if (basename($name) !== $name || !str_ends_with($name, '.png')) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid frame name.',
            ], 422);
        }

        $path = ResultEvidence::directoryFor($prediction) . '/' . $name;

        if (!Storage::exists($path)) {
            return response()->json([
                'success' => false,
                'message' => 'No thumbnail kept under that name.',
            ], 404);
        }

        return response(Storage::get($path), 200, [
            'Content-Type' => 'image/png',
            // Immutable: a thumbnail is rendered once and never rewritten.
            'Cache-Control' => 'private, max-age=86400',
        ]);
    }

    /**
     * POST /api/predictions/{id}/rerun
     *
     * Runs the same frames through a different model.
     *
     * The input frames are **copied**, not shared. Pointing two records at one
     * folder would mean deleting either job — or letting either expire — took
     * the other's inputs with it, and a comparison whose halves can vanish
     * separately is not a comparison.
     */
    public function rerun(Request $request, $id)
    {
        $request->validate(['model_id' => 'required|exists:models,id']);

        $original = $this->findOwned($request, $id);

        if (!$original->hasFiles()) {
            return response()->json([
                'success' => false,
                'message' => 'The original frames have expired and been deleted.',
            ], 410);
        }

        $model = Model::findOrFail($request->model_id);

        if (!$model->is_active) {
            return response()->json([
                'success' => false,
                'message' => "Model '{$model->name}' is not active.",
            ], 422);
        }

        $jobId = (string) \Illuminate\Support\Str::uuid();
        $base = "predictions/{$original->user_id}/{$jobId}";

        foreach (Storage::files($original->input_folder) as $file) {
            Storage::copy($file, "{$base}/input/" . basename($file));
        }

        Storage::makeDirectory("{$base}/output");

        $rerun = AnalysisRecord::create([
            'job_id' => $jobId,
            'user_id' => $original->user_id,
            'model_id' => $model->id,
            'rerun_of_id' => $original->rerun_of_id ?? $original->id,
            'file_name' => $original->file_name,
            'input_folder' => "{$base}/input",
            'output_folder' => "{$base}/output",
            'input_files_count' => $original->input_files_count,
            'status' => 'pending',
            'expires_at' => now()->addHours(24),
        ]);

        ProcessDeepLearningImage::dispatch($rerun);

        UserActivity::create([
            'user_id' => $original->user_id,
            'model_id' => $model->id,
            'activity_type' => 'prediction_rerun',
            'description' => "Re-ran job {$original->job_id} on model '{$model->name}'",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => ['original_id' => $original->id, 'rerun_id' => $rerun->id],
        ]);

        return response()->json([
            'success' => true,
            'message' => "Re-running on '{$model->name}'.",
            'data' => [
                'id' => $rerun->id,
                'job_id' => $rerun->job_id,
                'status' => $rerun->status,
                'rerun_of_id' => $rerun->rerun_of_id,
            ],
        ], 201);
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
        $request->validate(['kind' => 'nullable|in:input,output']);
        $kind = $request->input('kind');
        $size = (int) $request->input('size', 512);
        $size = max(64, min($size, 2048));

        $folders = match ($kind) {
            'input' => [$prediction->input_folder],
            'output' => [$prediction->output_folder],
            default => [$prediction->output_folder, $prediction->input_folder],
        };
        $source = collect($folders)
            ->map(fn($folder) => "{$folder}/{$name}")
            ->first(fn($path) => Storage::exists($path));

        if ($source === null) {
            return response()->json([
                'success' => false,
                'message' => 'Frame not found',
            ], 404);
        }

        $cacheKind = $kind ?? ($source === "{$prediction->output_folder}/{$name}" ? 'output' : 'input');
        $cachePath = "{$prediction->storageDirectory()}/preview/{$size}_{$cacheKind}_{$name}.png";

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
                'queue_position' => $this->getQueuePosition($prediction),
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

    public function downloadLink(Request $request, $id)
    {
        $request->validate(['kind' => 'required|in:results,complete']);
        $prediction = $this->findOwned($request, $id);
        abort_unless($prediction->status === 'completed', 409, 'Prediction is not completed yet.');
        abort_if($prediction->files_deleted_at, 410, 'Files have been deleted.');
        $path = \Illuminate\Support\Facades\URL::temporarySignedRoute(
            'api.downloads.predictions', now()->addMinutes(5),
            ['id' => $prediction->id, 'kind' => $request->kind, 'owner' => $request->user()->id],
            absolute: false
        );
        return response()->json(['success' => true, 'data' => ['path' => $path]]);
    }

    /** The signature authorizes this owner and this archive for five minutes. */
    public function signedDownload(Request $request, $id, string $kind)
    {
        $owner = \App\Models\User::findOrFail($request->query('owner'));
        abort_unless($owner->is_active && !$owner->must_change_password, 403);
        return $this->downloadZip($id, $kind, $owner);
    }

    /**
     * Create and stream ZIP download
     */
    private function downloadZip($id, $type = 'results', $signedOwner = null)
    {
        $user = $signedOwner ?? auth()->user();
        
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

                // Travels with the archive on purpose. Six months from now the
                // ZIP may be all that is left, and a folder of TIFFs cannot say
                // which of them came off the scanner and which the model drew —
                // let alone which were drawn between two frames it had drawn
                // itself. `generation` is 1 when both boundaries were scanned.
                'frame_provenance' => $prediction->frame_provenance,
                'validation' => $prediction->validation,
            ];
            $zip->addFromString('metadata.json', json_encode($metadata, JSON_PRETTY_PRINT));

            // A CSV beside the JSON, because the people who open these are as
            // likely to reach for a spreadsheet as for a parser. One row per
            // frame in the archive, and the first column is the only question
            // a folder of TIFFs cannot answer on its own.
            $zip->addFromString(
                'manifest.csv',
                app(ResultManifest::class)->csv($prediction, $inputFiles, $outputFiles)
            );
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

            // The kept thumbnails live outside that folder on purpose — they
            // are meant to survive expiry — so they need deleting by name.
            // Surviving expiry is not the same as surviving deletion.
            app(ResultEvidence::class)->forget($prediction);

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
