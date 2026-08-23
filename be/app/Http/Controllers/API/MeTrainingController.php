<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\TrainingMetric;
use App\Models\UserActivity;
use App\Services\TrainerDispatcher;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Training, from the researcher's side.
 *
 * The shape is deliberately the prediction pipeline's: upload an archive,
 * a job is queued, a remote GPU does the work, and the result comes back here.
 * Only the result differs — a prediction returns frames, a training run returns
 * numbers about how well the model learned.
 *
 * Everything is scoped to `$request->user()`. An administrator keeps oversight
 * through [TrainingController] — see everything, cancel anything — but starting
 * a run is no longer their errand.
 *
 * What a finished run does *not* do is become a model. The weights stay on the
 * platform; when a model is genuinely ready to serve, an administrator registers
 * its endpoint by hand, exactly as any other model is registered. Publishing is
 * a decision, not a consequence of a job finishing.
 */
class MeTrainingController extends Controller
{
    private const DATASET_DIR = 'training/datasets';

    /**
     * GET /api/me/training/jobs
     *
     * The caller's own runs, newest first.
     */
    public function index(Request $request)
    {
        $perPage = max(1, min((int) $request->input('per_page', 10), 100));

        $jobs = TrainingJob::where('created_by', $request->user()->id)
            ->with(['dataset:id,name,size_bytes', 'trainer:id,name,version,status'])
            ->orderByDesc('id')
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => collect($jobs->items())->map(fn ($j) => $this->serialise($j))->all(),
            'pagination' => [
                'total' => $jobs->total(),
                'per_page' => $jobs->perPage(),
                'current_page' => $jobs->currentPage(),
                'last_page' => $jobs->lastPage(),
            ],
            // The same honesty the prediction list carries: a job that will
            // never move should say so rather than sit at `queued` in silence.
            'meta' => [
                'trainer_available' => app(TrainerDispatcher::class)->pickTrainer() !== null,
            ],
        ]);
    }

    /**
     * POST /api/me/training/jobs
     *
     * Multipart: `name`, `archive` (a ZIP of frames), `total_epochs`, and
     * optionally `base_model_id` to fine-tune from an existing version rather
     * than from scratch.
     *
     * The dataset is uploaded in one request rather than in chunks. Prediction
     * uploads are resumable because a researcher uploads to them constantly and
     * from a phone; a training set is uploaded once, from a desk. If that turns
     * out to be wrong, the chunked machinery already exists to move to.
     */
    public function store(Request $request)
    {
        $maxBytes = (int) config('training.max_dataset_bytes');

        $validated = $request->validate([
            'name' => 'required|string|max:200',
            'description' => 'nullable|string|max:2000',
            'total_epochs' => 'required|integer|min:1|max:10000',
            'base_model_id' => 'nullable|exists:models,id',
            'hyperparameters' => 'nullable|array',
            'archive' => [
                'required', 'file',
                'max:' . intdiv($maxBytes, 1024),
                // Read from the file's contents, not its name. Android reports
                // a ZIP as octet-stream about as often as it reports it
                // correctly, which is why the third one is here.
                'mimetypes:application/zip,application/x-zip-compressed,application/octet-stream',
            ],
        ]);

        $file = $request->file('archive');
        $path = $file->store(self::DATASET_DIR);

        $dataset = TrainingDataset::create([
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
            'source_type' => 'upload',
            'archive_path' => $path,
            'size_bytes' => $file->getSize(),
            // Lets a worker prove it fetched the archive intact before spending
            // hours training on a truncated one.
            'checksum' => md5_file(Storage::path($path)),
            'uploaded_by' => $request->user()->id,
        ]);

        $job = TrainingJob::create([
            'name' => $validated['name'],
            'training_dataset_id' => $dataset->id,
            'base_model_id' => $validated['base_model_id'] ?? null,
            'total_epochs' => $validated['total_epochs'],
            'hyperparameters' => $validated['hyperparameters'] ?? [],
            'status' => 'queued',
            'created_by' => $request->user()->id,
        ]);

        $this->record($request, 'training_job_created',
            "Started training run: {$job->name}", ['job_id' => $job->id]);

        // Best effort, and never fatal. A queued job with no trainer reachable
        // is not a failed request — the run is recorded and a worker can claim
        // it later. Saying nothing at all would be the failure, so the reason
        // travels back in `dispatch_message`.
        $dispatch = app(TrainerDispatcher::class)->dispatch($job->load('dataset'));

        return response()->json([
            'success' => true,
            'message' => $dispatch['ok']
                ? 'Training started. Progress appears here as it reports back.'
                : 'Training run queued.',
            'dispatch_message' => $dispatch['ok'] ? null : $dispatch['message'],
            'data' => $this->serialise($job->fresh()->load('dataset', 'trainer')),
        ], 201);
    }

    /**
     * GET /api/me/training/jobs/{id}
     *
     * The run and its full metric history — which is the answer to "how good
     * did this model get", and the reason the history is kept at all.
     */
    public function show(Request $request, $id)
    {
        $job = $this->ownedJob($request, $id);

        $history = TrainingMetric::where('training_job_id', $job->id)
            ->orderBy('epoch')
            ->get(['epoch', 'metrics', 'recorded_at']);

        return response()->json([
            'success' => true,
            'data' => $this->serialise($job) + [
                'hyperparameters' => $job->hyperparameters ?? [],
                'error_message' => $job->error_message,
                'worker_label' => $job->worker_label,
                'history' => $history->map(fn ($m) => [
                    'epoch' => $m->epoch,
                    'metrics' => $m->metrics,
                    'recorded_at' => $m->recorded_at?->toIso8601String(),
                ])->all(),
            ],
        ]);
    }

    /**
     * POST /api/me/training/jobs/{id}/cancel
     *
     * A worker still holding it finds out on its next heartbeat, which is
     * answered with `cancelled` so it stops rather than burning GPU hours on a
     * run nobody wants.
     */
    public function cancel(Request $request, $id)
    {
        $job = $this->ownedJob($request, $id);

        if ($job->isFinished()) {
            return response()->json([
                'success' => false,
                'message' => 'This run has already finished.',
            ], 409);
        }

        $job->update(['status' => 'cancelled', 'finished_at' => now()]);

        $this->record($request, 'training_job_cancelled',
            "Cancelled training run: {$job->name}", ['job_id' => $job->id]);

        return response()->json([
            'success' => true,
            'message' => 'Run cancelled.',
            'data' => $this->serialise($job->fresh()->load('dataset', 'trainer')),
        ]);
    }

    // ------------------------------------------------------------- plumbing

    /**
     * The caller's job, or a 404.
     *
     * 404 rather than 403 on someone else's: telling an unauthorised caller
     * that a run exists is itself a leak.
     */
    /** GET /api/me/training/jobs/{id}/samples — which epochs have one. */
    public function samples(Request $request, $id)
    {
        $job = $this->ownedJob($request, $id);

        return response()->json([
            'success' => true,
            'data' => $job->samples()
                ->get()
                ->map(fn($s) => ['epoch' => $s->epoch])
                ->values(),
        ]);
    }

    /** GET /api/me/training/jobs/{id}/samples/{epoch} — the PNG itself. */
    public function sampleImage(Request $request, $id, $epoch)
    {
        $job = $this->ownedJob($request, $id);

        $sample = $job->samples()->where('epoch', (int) $epoch)->first();

        if (!$sample || !Storage::exists($sample->path)) {
            abort(404);
        }

        return response()->file(Storage::path($sample->path), [
            'Content-Type' => 'image/png',
            // A sample for a given epoch never changes once written.
            'Cache-Control' => 'private, max-age=3600',
        ]);
    }

    private function ownedJob(Request $request, $id): TrainingJob
    {
        return TrainingJob::with(['dataset:id,name,size_bytes', 'trainer:id,name,version,status'])
            ->where('created_by', $request->user()->id)
            ->findOrFail($id);
    }

    private function serialise(TrainingJob $job): array
    {
        return [
            'id' => $job->id,
            'name' => $job->name,
            'status' => $job->status,
            'total_epochs' => $job->total_epochs,
            'current_epoch' => $job->current_epoch,
            'progress_percent' => $job->total_epochs > 0
                ? round($job->current_epoch / $job->total_epochs * 100, 1)
                : 0,
            'metrics' => $job->metrics ?? [],
            'dataset' => $job->dataset ? [
                'id' => $job->dataset->id,
                'name' => $job->dataset->name,
                'size_bytes' => $job->dataset->size_bytes,
            ] : null,
            'trainer' => $job->trainer ? [
                'id' => $job->trainer->id,
                'name' => $job->trainer->name,
                'status' => $job->trainer->status,
            ] : null,
            'created_at' => $job->created_at?->toIso8601String(),
            'started_at' => $job->started_at?->toIso8601String(),
            'finished_at' => $job->finished_at?->toIso8601String(),
        ];
    }

    private function record(Request $request, string $type, string $description, array $metadata = []): void
    {
        UserActivity::create([
            'user_id' => $request->user()->id,
            'activity_type' => $type,
            'description' => $description,
            'metadata' => $metadata,
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);
    }
}
