<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\TrainingMetric;
use App\Models\UserActivity;
use App\Services\TrainerDispatcher;
use App\Services\TiffPreview;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use ZipArchive;

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

        $queue = $this->queuePositions();

        return response()->json([
            'success' => true,
            'data' => collect($jobs->items())
                ->map(fn ($j) => $this->serialise($j) + [
                    'queue_position' => $queue['positions'][$j->id] ?? null,
                ])
                ->all(),
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
                'queued_total' => $queue['queued'],
                'running_total' => $queue['running'],
            ],
        ]);
    }

    /**
     * Where each queued run sits in line, and how busy the line is.
     *
     * Everyone's runs, not one account's: a position counted within your own
     * uploads would say "1" while five other people were ahead of you. Same
     * rule as the prediction queue, for the same reason.
     *
     * **No wait estimate.** The prediction board can offer one because every
     * run is the same shape of work; a training run is however many epochs the
     * researcher asked for, so the job ahead of you might take four minutes or
     * four hours. A number with that much spread is worse than no number —
     * people plan around it and then it is wrong. The position is real, and it
     * is what was actually asked for.
     *
     * @return array{positions: array<int, int>, queued: int, running: int}
     */
    private function queuePositions(): array
    {
        $positions = [];
        $place = 0;

        foreach (
            TrainingJob::where('status', 'queued')
                ->orderBy('created_at')
                ->pluck('id') as $id
        ) {
            $positions[$id] = ++$place;
        }

        return [
            'positions' => $positions,
            'queued' => $place,
            'running' => TrainingJob::where('status', 'running')->count(),
        ];
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
                // Object, not array — the same reason as [serialise()]'s
                // `metrics`, one line of which this was the twin all along.
                'hyperparameters' => (object) ($job->hyperparameters ?? []),
                'error_message' => $job->error_message,
                'worker_label' => $job->worker_label,
                'history' => $history->map(fn ($m) => [
                    'epoch' => $m->epoch,
                    // Object, not array — see the note in [serialise()].
                    'metrics' => (object) ($m->metrics ?? []),
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

    /**
     * GET /api/me/training/jobs/{id}/dataset/frames
     *
     * Read from inside the archive rather than extracting it. A dataset is the
     * largest thing this platform stores, and doubling it on disk to look at
     * it would be absurd — ZipArchive reads the central directory at the end
     * of the file, so listing costs the entry count and not the size.
     */
    public function datasetFrames(Request $request, $id)
    {
        $job = $this->ownedJob($request, $id);

        $dataset = TrainingDataset::find($job->training_dataset_id);

        return response()->json([
            'success' => true,
            'data' => $this->archiveFrames($job)->values(),
            // An archive swept by `training:cleanup` leaves `archiveFrames()`
            // returning an empty collection, which reads exactly like an
            // archive that never held any frames. Say which it is: the run's
            // numbers are still here, the frames behind them are not.
            'meta' => [
                'archive_deleted' => (bool) $dataset?->archiveExpired(),
                'archive_deleted_at' => $dataset?->archive_deleted_at?->toIso8601String(),
            ],
        ]);
    }

    /**
     * GET /api/me/training/jobs/{id}/dataset/frames/{name}/preview
     *
     * The frames are 16-bit TIFFs, which neither a browser nor Flutter can
     * decode, so TiffPreview renders them here — the same path a prediction
     * frame takes.
     */
    public function datasetFramePreview(Request $request, $id, string $name, TiffPreview $preview)
    {
        $job = $this->ownedJob($request, $id);

        $size = (int) $request->input('size', 512);
        $size = max(64, min($size, 2048));

        // Checked against the archive's own listing rather than sanitised. A
        // name that reaches getFromName() unchecked reads whatever it points
        // at, and basename() alone would still accept an entry this dataset
        // does not have.
        $known = $this->archiveFrames($job)->firstWhere('name', $name);

        if ($known === null) {
            abort(404);
        }

        $cachePath = "training/datasets/preview/{$job->training_dataset_id}/{$size}_{$name}.png";

        if (!Storage::exists($cachePath)) {
            $zip = new ZipArchive();

            $archive = TrainingDataset::whereKey($job->training_dataset_id)
                ->value('archive_path');

            if ($zip->open(Storage::path($archive)) !== true) {
                abort(404);
            }

            $tiff = $zip->getFromName($name);
            $zip->close();

            if ($tiff === false) {
                abort(404);
            }

            Storage::put($cachePath, $preview->toPng($tiff, $size));
        }

        return response()->file(Storage::path($cachePath), [
            'Content-Type' => 'image/png',
            // An entry inside an archive never changes.
            'Cache-Control' => 'private, max-age=3600',
        ]);
    }

    /**
     * The `.tif` entries in a job's dataset archive, sorted by name.
     *
     * Sorted because the numbering in the names is the sequence — the same
     * thing the trainer builds its triples from.
     *
     * @return \Illuminate\Support\Collection<int, array{name:string, size:int}>
     */
    private function archiveFrames(TrainingJob $job)
    {
        // Fetched rather than read off `$job->dataset`: ownedJob() eager-loads
        // that relation as `id,name,size_bytes` on purpose, and widening it
        // would put the storage path into every job payload. Where the archive
        // sits on disk is nobody's business but this method's.
        $path = TrainingDataset::whereKey($job->training_dataset_id)
            ->value('archive_path');

        if (!$path || !Storage::exists($path)) {
            return collect();
        }

        $zip = new ZipArchive();

        if ($zip->open(Storage::path($path)) !== true) {
            return collect();
        }

        $entries = collect();

        for ($i = 0; $i < $zip->numFiles; $i++) {
            $stat = $zip->statIndex($i);
            $name = $stat['name'];

            // Folder entries, and anything a researcher zipped in beside the
            // frames — a README is not a frame.
            if (str_ends_with($name, '/')) {
                continue;
            }

            $lower = strtolower($name);
            if (!str_ends_with($lower, '.tif') && !str_ends_with($lower, '.tiff')) {
                continue;
            }

            $entries->push(['name' => $name, 'size' => (int) $stat['size']]);
        }

        $zip->close();

        return $entries->sortBy('name')->values();
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
            // An object, never an array — the third time this exact edge has
            // bitten. PHP has one array type and `json_encode` renders the
            // empty one as `[]`, so a run that has reported nothing yet reached
            // the client as a JSON list where a map was declared. Dart's
            // `as Map?` on a List **throws** rather than yielding null, and the
            // screen's catch only covered `ApiException` — so MY RUNS span for
            // ever, on web and on the phone, with nothing anywhere saying why.
            'metrics' => (object) ($job->metrics ?? []),
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
