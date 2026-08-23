<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\TrainingJob;
use App\Models\TrainingSample;
use App\Models\TrainingMetric;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Managed model training — the GPU worker's half.
 *
 * Authenticated by a shared secret rather than a user token; see
 * [EnsureTrainingWorker] for why.
 *
 * The whole protocol is built around one fact: **the worker will die.** A
 * Kaggle session lasts 9–12 hours and training takes days, so a session ending
 * is the normal course of events, not an error. Nothing here treats silence as
 * failure — a job whose worker goes quiet returns to `queued` with its
 * checkpoint intact and the next worker carries on from there.
 */
class TrainingWorkerController extends Controller
{
    private const CHECKPOINT_DIR = 'training/checkpoints';
    private const WEIGHTS_DIR = 'training/weights';

    /**
     * POST /api/training/worker/claim
     *
     * Take the oldest queued job, if there is one.
     */
    public function claim(Request $request)
    {
        $validated = $request->validate([
            'worker_label' => 'nullable|string|max:100',
        ]);

        // Locked so two notebooks starting at once cannot claim the same job
        // and train it twice on the same GPU quota.
        $job = DB::transaction(function () use ($validated) {
            $candidate = TrainingJob::where('status', 'queued')
                ->orderBy('created_at')
                ->lockForUpdate()
                ->first();

            if (!$candidate) return null;

            $candidate->update([
                'status' => 'claimed',
                'worker_label' => $validated['worker_label'] ?? 'unnamed worker',
                'claimed_at' => now(),
                'heartbeat_at' => now(),
                'started_at' => $candidate->started_at ?? now(),
                'error_message' => null,
            ]);

            return $candidate;
        });

        if (!$job) {
            return response()->json([
                'success' => true,
                'message' => 'Nothing queued.',
                'data' => null,
            ]);
        }

        $job->load('dataset', 'baseModel:id,name,version,file_path');

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $job->id,
                'name' => $job->name,
                'total_epochs' => $job->total_epochs,
                // Where to resume from. Null on a fresh job; set when a
                // previous worker died mid-run and left a checkpoint.
                'resume_from_epoch' => $job->current_epoch,
                'has_checkpoint' => $job->checkpoint_path !== null,
                'hyperparameters' => $job->hyperparameters ?? [],
                'dataset' => [
                    'id' => $job->dataset->id,
                    'name' => $job->dataset->name,
                    'source_type' => $job->dataset->source_type,
                    // One of these is set. `url` means fetch it yourself;
                    // `download` means pull it from us.
                    'source_url' => $job->dataset->source_url,
                    'download_path' => $job->dataset->isHosted()
                        ? "/training/worker/jobs/{$job->id}/dataset"
                        : null,
                    'checksum' => $job->dataset->checksum,
                ],
                'base_model' => $job->baseModel ? [
                    'name' => $job->baseModel->name,
                    'version' => $job->baseModel->version,
                ] : null,
                'heartbeat_seconds' => 60,
                'stale_after_minutes' => TrainingJob::STALE_AFTER_MINUTES,
            ],
        ]);
    }

    /** GET /api/training/worker/jobs/{id}/dataset */
    public function dataset($id)
    {
        $job = TrainingJob::with('dataset')->findOrFail($id);
        $dataset = $job->dataset;

        if (!$dataset || !$dataset->archive_path || !Storage::exists($dataset->archive_path)) {
            return response()->json([
                'success' => false,
                'message' => 'This dataset is not hosted here.',
            ], 404);
        }

        return response()->download(
            Storage::path($dataset->archive_path),
            "dataset-{$dataset->id}.zip",
            ['X-Checksum-MD5' => $dataset->checksum ?? ''],
        );
    }

    /**
     * POST /api/training/worker/jobs/{id}/heartbeat
     *
     * "Still alive", plus whatever progress there is. The response tells the
     * worker whether to keep going — an administrator may have cancelled the
     * job, and the worker should stop rather than burn hours on it.
     */
    public function heartbeat(Request $request, $id)
    {
        $validated = $request->validate([
            'current_epoch' => 'nullable|integer|min:0',
            'metrics' => 'nullable|array',
        ]);

        $job = TrainingJob::findOrFail($id);

        if ($job->isFinished()) {
            return response()->json([
                'success' => true,
                'message' => "This job is {$job->status}.",
                'data' => ['continue' => false, 'status' => $job->status],
            ]);
        }

        $job->update(array_filter([
            'status' => 'running',
            'heartbeat_at' => now(),
            'current_epoch' => $validated['current_epoch'] ?? null,
            'metrics' => $validated['metrics'] ?? null,
        ], fn($v) => $v !== null));

        // The job row keeps only the latest numbers. Keeping the history is
        // what lets the researcher be shown a curve rather than a single figure
        // whose only context is "so far".
        TrainingMetric::record(
            $job->id,
            (int) ($validated['current_epoch'] ?? 0),
            $validated['metrics'] ?? null,
        );

        return response()->json([
            'success' => true,
            'data' => ['continue' => true, 'status' => 'running'],
        ]);
    }

    /**
     * POST /api/training/worker/jobs/{id}/checkpoint
     *
     * Partial weights, so a session that dies later costs hours rather than
     * days. This is the single most important call in the protocol.
     */
    public function checkpoint(Request $request, $id)
    {
        $maxBytes = (int) config('training.max_weights_bytes');

        $validated = $request->validate([
            'current_epoch' => 'required|integer|min:0',
            'metrics' => 'nullable|array',
            'weights' => ['required', 'file', 'max:' . intdiv($maxBytes, 1024)],
        ]);

        $job = TrainingJob::findOrFail($id);

        if ($job->isFinished()) {
            return response()->json([
                'success' => false,
                'message' => "This job is {$job->status}; the checkpoint was not stored.",
            ], 409);
        }

        // The previous checkpoint goes only after the new one is safely on
        // disk: losing both to a failed write would cost the whole run.
        $previous = $job->checkpoint_path;
        $path = $request->file('weights')->store(self::CHECKPOINT_DIR);

        $job->update([
            'status' => 'running',
            'checkpoint_path' => $path,
            'current_epoch' => $validated['current_epoch'],
            'metrics' => $validated['metrics'] ?? $job->metrics,
            'heartbeat_at' => now(),
        ]);

        TrainingMetric::record(
            $job->id,
            (int) $validated['current_epoch'],
            $validated['metrics'] ?? null,
        );

        if ($previous && $previous !== $path && Storage::exists($previous)) {
            Storage::delete($previous);
        }

        return response()->json([
            'success' => true,
            'message' => 'Checkpoint stored.',
            'data' => ['continue' => true, 'current_epoch' => $job->current_epoch],
        ]);
    }

    /** POST /api/training/worker/jobs/{id}/complete — final weights. */
    public function complete(Request $request, $id)
    {
        $maxBytes = (int) config('training.max_weights_bytes');

        $validated = $request->validate([
            'metrics' => 'nullable|array',
            'weights' => ['required', 'file', 'max:' . intdiv($maxBytes, 1024)],
        ]);

        $job = TrainingJob::findOrFail($id);

        if ($job->isFinished()) {
            return response()->json([
                'success' => false,
                'message' => "This job is already {$job->status}.",
            ], 409);
        }

        $path = $request->file('weights')->store(self::WEIGHTS_DIR);

        $job->update([
            'status' => 'completed',
            'weights_path' => $path,
            'metrics' => $validated['metrics'] ?? $job->metrics,
            'current_epoch' => $job->total_epochs,
            'heartbeat_at' => now(),
            'finished_at' => now(),
            'error_message' => null,
        ]);

        TrainingMetric::record(
            $job->id,
            (int) $job->total_epochs,
            $validated['metrics'] ?? null,
        );

        // The checkpoint has served its purpose and is the larger of the two.
        if ($job->checkpoint_path && Storage::exists($job->checkpoint_path)) {
            Storage::delete($job->checkpoint_path);
            $job->update(['checkpoint_path' => null]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Training recorded. The weights stay on the platform; '
                . 'an administrator registers an endpoint when a model is ready '
                . 'to serve.',
        ]);
    }

    /**
     * POST /api/training/worker/jobs/{id}/fail
     *
     * The worker saying it cannot continue — bad data, out of memory, a bug in
     * the notebook. Distinct from going quiet, which is not a failure and is
     * handled by the reclaim sweep instead.
     */
    /**
     * POST /api/training/worker/jobs/{id}/sample — one rendered frame.
     *
     * Sent at the end of each epoch, from a fixed test triplet, so scrubbing
     * through them shows the model improving rather than the triplets
     * changing.
     */
    public function sample(Request $request, $id)
    {
        $job = TrainingJob::findOrFail($id);

        $validated = $request->validate([
            'epoch' => 'required|integer|min:0',
            'image' => [
                'required',
                'file',
                // 4 MB, matching the news photo. A sample PNG has no reason to
                // be larger, and without a ceiling a confused worker could
                // fill the disk over a run of hundreds of epochs.
                'max:4096',
                'mimetypes:image/png',
            ],
        ]);

        // Deleted through Eloquent so the old file goes with the row. A worker
        // repeating an epoch after losing its session is normal here.
        TrainingSample::where('training_job_id', $job->id)
            ->where('epoch', $validated['epoch'])
            ->first()
            ?->delete();

        $path = $request->file('image')->store("training/samples/{$job->id}");

        $sample = TrainingSample::create([
            'training_job_id' => $job->id,
            'epoch' => $validated['epoch'],
            'path' => $path,
        ]);

        return response()->json([
            'success' => true,
            'data' => ['epoch' => $sample->epoch],
        ]);
    }

    public function fail(Request $request, $id)
    {
        $validated = $request->validate([
            'message' => 'required|string|max:2000',
        ]);

        $job = TrainingJob::findOrFail($id);

        if ($job->isFinished()) {
            return response()->json([
                'success' => false,
                'message' => "This job is already {$job->status}.",
            ], 409);
        }

        $job->update([
            'status' => 'failed',
            'error_message' => $validated['message'],
            'finished_at' => now(),
        ]);

        return response()->json(['success' => true, 'message' => 'Failure recorded.']);
    }
}
