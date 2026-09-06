<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Model;
use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\UserActivity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

/**
 * Managed model training — the administrator's half.
 *
 * The platform never trains anything; it records what should be trained and
 * what came back. The GPU lives on Kaggle and its half of the conversation is
 * in [TrainingWorkerController].
 */
class TrainingController extends Controller
{
    private const DATASET_DIR = 'training/datasets';

    // ---------------------------------------------------------- datasets

    /** GET /api/admin/training/datasets */
    public function datasets(Request $request)
    {
        $datasets = TrainingDataset::with('uploader:id,name')
            ->withCount('jobs')
            ->orderByDesc('id')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $datasets->map(fn($d) => $this->serialiseDataset($d))->all(),
        ]);
    }

    /**
     * POST /api/admin/training/datasets
     *
     * A URL the worker fetches for itself. **Not an upload.**
     *
     * The upload path was removed from this endpoint on purpose. An
     * administrator registering a dataset is recording where data already
     * lives — Kaggle, Drive, an institutional share — and pushing 20 GB up a
     * home tunnel only for the GPU host to pull it back down again is absurd
     * when the worker has a fast link and can fetch it directly.
     *
     * Researchers upload; that is [MeTrainingController], and it goes through
     * the resumable chunked path because a laptop on hotel wifi is exactly the
     * case a single multipart POST cannot survive.
     */
    public function storeDataset(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:200',
            'description' => 'nullable|string|max:2000',
            'source_url' => 'required|url|max:2048',
            'frame_count' => 'nullable|integer|min:0',
        ]);

        $dataset = new TrainingDataset([
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
            'source_type' => 'url',
            'source_url' => $validated['source_url'],
            'frame_count' => $validated['frame_count'] ?? null,
            'uploaded_by' => $request->user()->id,
        ]);

        $dataset->save();

        $this->record($request, 'training_dataset_added', "Added training dataset: {$dataset->name}", [
            'dataset_id' => $dataset->id,
            'source_type' => $dataset->source_type,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Dataset registered.',
            'data' => $this->serialiseDataset($dataset->fresh()->load('uploader')),
        ], 201);
    }

    /** DELETE /api/admin/training/datasets/{id} */
    public function destroyDataset(Request $request, $id)
    {
        $dataset = TrainingDataset::findOrFail($id);

        // A dataset a job is still working from cannot go: the worker would
        // lose its source mid-run, and the job's record would point at
        // nothing.
        $inUse = $dataset->jobs()
            ->whereIn('status', array_merge(TrainingJob::ACTIVE, ['queued']))
            ->exists();

        if ($inUse) {
            return response()->json([
                'success' => false,
                'message' => 'A training job is still using this dataset. Cancel it first.',
            ], 409);
        }

        if ($dataset->archive_path && Storage::exists($dataset->archive_path)) {
            Storage::delete($dataset->archive_path);
        }

        $name = $dataset->name;
        $dataset->delete();

        $this->record($request, 'training_dataset_deleted', "Deleted training dataset: {$name}");

        return response()->json(['success' => true, 'message' => 'Dataset deleted.']);
    }

    // -------------------------------------------------------------- jobs

    /** GET /api/admin/training/jobs */
    public function jobs(Request $request)
    {
        $perPage = max(1, min((int) $request->input('per_page', 15), 100));

        $query = TrainingJob::with([
            'dataset:id,name,source_type',
            'baseModel:id,name,version',
            'creator:id,name',
        ]);

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        $jobs = $query->orderByDesc('id')->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => collect($jobs->items())->map(fn($j) => $this->serialiseJob($j))->all(),
            'pagination' => [
                'total' => $jobs->total(),
                'per_page' => $jobs->perPage(),
                'current_page' => $jobs->currentPage(),
                'last_page' => $jobs->lastPage(),
                'from' => $jobs->firstItem(),
                'to' => $jobs->lastItem(),
            ],
            'meta' => [
                'queued_count' => TrainingJob::where('status', 'queued')->count(),
                'running_count' => TrainingJob::whereIn('status', TrainingJob::ACTIVE)->count(),
                // Nothing will move while this is zero and jobs are queued,
                // which is the first thing to check when a job "does nothing".
                'worker_configured' => !empty(config('training.worker_token')),
            ],
        ]);
    }

    /** GET /api/admin/training/jobs/{id} */
    public function showJob($id)
    {
        $job = TrainingJob::with([
            'dataset', 'baseModel:id,name,version', 'creator:id,name',
            'resultingModel:id,name,version',
        ])->findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $this->serialiseJob($job, detailed: true),
        ]);
    }


    /** POST /api/admin/training/jobs/{id}/cancel */
    public function cancelJob(Request $request, $id)
    {
        $job = TrainingJob::findOrFail($id);

        if ($job->isFinished()) {
            return response()->json([
                'success' => false,
                'message' => 'This job has already finished.',
            ], 409);
        }

        $job->update([
            'status' => 'cancelled',
            'finished_at' => now(),
        ]);

        // A worker still holding it learns on its next heartbeat, which is
        // answered with `cancelled` so it can stop rather than train on into
        // a job nobody wants.
        $this->record($request, 'training_job_cancelled', "Cancelled training job: {$job->name}", [
            'job_id' => $job->id,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Job cancelled.',
            'data' => $this->serialiseJob($job->fresh()->load('dataset')),
        ]);
    }

    /** DELETE /api/admin/training/jobs/{id} */
    public function destroyJob(Request $request, $id)
    {
        $job = TrainingJob::findOrFail($id);

        if ($job->isHeldByWorker()) {
            return response()->json([
                'success' => false,
                'message' => 'A worker is holding this job. Cancel it first.',
            ], 409);
        }

        foreach ([$job->checkpoint_path, $job->weights_path] as $path) {
            if ($path && Storage::exists($path)) Storage::delete($path);
        }

        $name = $job->name;
        $job->delete();

        $this->record($request, 'training_job_deleted', "Deleted training job: {$name}");

        return response()->json(['success' => true, 'message' => 'Job deleted.']);
    }

    /**
     * POST /api/admin/training/jobs/{id}/register-model
     *
     * Turns finished weights into a row in the model registry.
     *
     * Deliberately a separate, explicit step. Weights are a file; a *model* in
     * this platform is a running FastAPI worker with a URL. Nothing here can
     * deploy a `.h5` to a GPU, so pretending completion produced a usable model
     * would be a lie the researcher discovers only when a prediction fails.
     * The new row starts inactive and offline until someone deploys it and
     * fills in the endpoint.
     */
    public function registerModel(Request $request, $id)
    {
        $job = TrainingJob::findOrFail($id);

        if ($job->status !== 'completed' || !$job->weights_path) {
            return response()->json([
                'success' => false,
                'message' => 'This job has no finished weights to register.',
            ], 409);
        }

        if ($job->resulting_model_id) {
            return response()->json([
                'success' => false,
                'message' => 'These weights are already registered as a model.',
            ], 409);
        }

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'version' => 'required|string|max:50',
            'endpoint_url' => 'nullable|url|max:255',
            'description' => 'nullable|string|max:2000',
        ]);

        $accuracy = $job->metrics['accuracy'] ?? null;

        $model = Model::create([
            'name' => $validated['name'],
            'version' => $validated['version'],
            'endpoint_url' => $validated['endpoint_url'] ?? null,
            'file_path' => $job->weights_path,
            'description' => $validated['description']
                ?? "Trained by job #{$job->id} on dataset "
                    . ($job->dataset->name ?? 'unknown'),
            'accuracy' => is_numeric($accuracy) ? $accuracy : null,
            'status' => 'offline',
            // Off until someone deploys the weights and confirms the endpoint.
            // An inactive model is invisible to researchers, so nobody can
            // queue work against something that is not serving yet.
            'is_active' => false,
        ]);

        $job->update(['resulting_model_id' => $model->id]);

        $this->record($request, 'training_model_registered',
            "Registered {$model->name} {$model->version} from training job #{$job->id}", [
                'job_id' => $job->id,
                'model_id' => $model->id,
            ]);

        return response()->json([
            'success' => true,
            'message' => 'Registered as an inactive model. Deploy the weights, '
                . 'set its endpoint, then activate it.',
            'data' => $this->serialiseJob($job->fresh()->load(['dataset', 'resultingModel'])),
        ], 201);
    }

    /** GET /api/admin/training/jobs/{id}/weights — download what came back. */
    public function downloadWeights($id)
    {
        $job = TrainingJob::findOrFail($id);

        $path = $job->weights_path ?? $job->checkpoint_path;

        if (!$path || !Storage::exists($path)) {
            return response()->json([
                'success' => false,
                'message' => 'Nothing has been uploaded for this job yet.',
            ], 404);
        }

        return response()->download(
            Storage::path($path),
            "job-{$job->id}-" . basename($path),
        );
    }

    // ----------------------------------------------------------- helpers

    private function serialiseDataset(TrainingDataset $dataset): array
    {
        return [
            'id' => $dataset->id,
            'name' => $dataset->name,
            'description' => $dataset->description,
            'source_type' => $dataset->source_type,
            'source_url' => $dataset->source_url,
            'size_bytes' => $dataset->size_bytes,
            'frame_count' => $dataset->frame_count,
            'checksum' => $dataset->checksum,
            'jobs_count' => $dataset->jobs_count ?? $dataset->jobs()->count(),
            'uploaded_by' => $dataset->relationLoaded('uploader') && $dataset->uploader
                ? $dataset->uploader->name
                : null,
            'created_at' => $dataset->created_at?->toIso8601String(),
        ];
    }

    private function serialiseJob(TrainingJob $job, bool $detailed = false): array
    {
        $data = [
            'id' => $job->id,
            'name' => $job->name,
            'status' => $job->status,
            'current_epoch' => $job->current_epoch,
            'total_epochs' => $job->total_epochs,
            'progress' => $job->progress(),
            // Object or null, never an empty array — see the note in
            // MeTrainingController::serialise(). The admin console parses this
            // the same way the researcher's does.
            'metrics' => $job->metrics === null ? null : (object) $job->metrics,
            'worker_label' => $job->worker_label,
            'trainer_url' => $job->trainer_url,
            'dispatched_at' => $job->dispatched_at?->toIso8601String(),
            'error_message' => $job->error_message,
            'has_weights' => $job->weights_path !== null,
            'has_checkpoint' => $job->checkpoint_path !== null,
            'dataset' => $job->relationLoaded('dataset') && $job->dataset
                ? ['id' => $job->dataset->id, 'name' => $job->dataset->name]
                : null,
            'base_model' => $job->relationLoaded('baseModel') && $job->baseModel
                ? [
                    'id' => $job->baseModel->id,
                    'name' => $job->baseModel->name,
                    'version' => $job->baseModel->version,
                ]
                : null,
            'resulting_model_id' => $job->resulting_model_id,
            'heartbeat_at' => $job->heartbeat_at?->toIso8601String(),
            'started_at' => $job->started_at?->toIso8601String(),
            'finished_at' => $job->finished_at?->toIso8601String(),
            'created_at' => $job->created_at?->toIso8601String(),
        ];

        if ($detailed) {
            $data['hyperparameters'] = (object) ($job->hyperparameters ?? []);
            $data['created_by'] = $job->relationLoaded('creator') && $job->creator
                ? $job->creator->name
                : null;
        }

        return $data;
    }

    /**
     * True when a remote worker could not possibly call this address back.
     *
     * Only the cases that are certainly wrong: an empty value, and the loopback
     * names. A LAN address may be perfectly correct when the GPU is on the same
     * network, so it is not refused.
     */
    private function isUnreachableFromOutside(string $callback): bool
    {
        if ($callback === '') return true;

        $host = parse_url($callback, PHP_URL_HOST);

        return in_array($host, ['localhost', '127.0.0.1', '::1', '0.0.0.0'], true);
    }

    /** Guzzle messages carry the whole URL and stack noise; trim them. */
    private function trim(string $message): string
    {
        $message = strtok($message, "
");

        return strlen($message) > 180 ? substr($message, 0, 180) . '...' : $message;
    }

    private function record(Request $request, string $type, string $description, array $metadata = []): void
    {
        UserActivity::create([
            'user_id' => $request->user()->id,
            'activity_type' => $type,
            'description' => $description,
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => $metadata ?: null,
        ]);
    }
}
