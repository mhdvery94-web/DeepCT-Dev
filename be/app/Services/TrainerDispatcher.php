<?php

namespace App\Services;

use App\Models\Model;
use App\Models\TrainingJob;
use Illuminate\Support\Facades\Http;

/**
 * Hands a training job to a GPU host.
 *
 * This is the training twin of dispatching a prediction to a model endpoint,
 * and it exists as a service rather than a controller method because two
 * callers need it now: an administrator pressing "send to trainer", and a
 * researcher starting a run of their own.
 *
 * The trainer is chosen from the model registry — `kind = 'trainer'` — so
 * turning training on or off is the same act as turning a model on or off, and
 * needs no second screen.
 */
class TrainerDispatcher
{
    /**
     * @return array{ok: bool, message: string, status: int, trainer?: Model}
     */
    public function dispatch(TrainingJob $job, ?string $explicitUrl = null): array
    {
        if ($job->status !== 'queued') {
            return $this->fail("This job is {$job->status}; only a queued job can be dispatched.", 409);
        }

        $trainer = $this->pickTrainer();

        $trainerUrl = $explicitUrl
            ?? $job->trainer_url
            ?? $trainer?->endpoint_url
            ?? config('training.trainer_url');

        if (empty($trainerUrl)) {
            return $this->fail(
                'No trainer endpoint is available. An administrator registers one '
                . 'in the model registry, the same way an inference model is added.',
                422
            );
        }

        $token = config('training.worker_token');

        if (empty($token)) {
            return $this->fail(
                'No worker token is configured, so the trainer would have no way '
                . 'to report back.',
                422
            );
        }

        $callback = rtrim((string) config('training.callback_url'), '/');

        // A GPU host on the other side of the internet cannot reach
        // `http://localhost`, and `APP_URL` is left at that default on almost
        // every development machine. Without this check the dispatch succeeds,
        // the trainer accepts, and then every callback it makes fails silently
        // — the job sits at `queued` forever and nothing says why.
        if ($this->isUnreachableFromOutside($callback)) {
            return $this->fail(
                'The callback address is ' . ($callback ?: 'empty')
                . ', which the GPU host cannot reach. Set TRAINING_CALLBACK_URL '
                . '(or APP_URL) to an address reachable from outside this machine.',
                422
            );
        }

        $dataset = $job->dataset;

        try {
            $response = Http::timeout((int) config('training.dispatch_timeout', 30))
                ->withoutVerifying() // tunnel certificates
                ->withHeaders(['ngrok-skip-browser-warning' => 'true'])
                ->post($trainerUrl, [
                    'job_id' => $job->id,
                    'name' => $job->name,
                    'total_epochs' => $job->total_epochs,
                    'resume_from_epoch' => $job->current_epoch,
                    'hyperparameters' => $job->hyperparameters ?? [],
                    'dataset' => [
                        'id' => $dataset?->id,
                        'name' => $dataset?->name,
                        'source_type' => $dataset?->source_type,
                        'source_url' => $dataset?->source_url,
                        'download_url' => $dataset && $dataset->isHosted()
                            ? "{$callback}/api/training/worker/jobs/{$job->id}/dataset"
                            : null,
                        'checksum' => $dataset?->checksum,
                    ],
                    // Everything the trainer needs to report back with. Without
                    // these it could train perfectly and still have nowhere to
                    // put the result.
                    'callback' => [
                        'base_url' => "{$callback}/api",
                        'worker_token' => $token,
                        'heartbeat_seconds' => 60,
                    ],
                ]);
        } catch (\Throwable $e) {
            return $this->fail('Could not reach the trainer: ' . $this->trim($e->getMessage()), 502);
        }

        if (!$response->successful()) {
            return $this->fail("The trainer refused the job (HTTP {$response->status()}).", 502);
        }

        // Deliberately still `queued`, not `running`. The trainer says it
        // *accepted* the job; only its first heartbeat proves it started. A
        // job marked running by us and never actually begun would sit there
        // looking healthy forever.
        $job->update([
            'trainer_url' => $trainerUrl,
            'trainer_model_id' => $trainer?->id,
            'dispatched_at' => now(),
            'error_message' => null,
        ]);

        return [
            'ok' => true,
            'status' => 200,
            'message' => 'The trainer accepted the job. It reports back as it trains.',
            'trainer' => $trainer,
        ];
    }

    /**
     * The trainer to use when nobody named one.
     *
     * Online first, then anything active. An offline-but-registered trainer is
     * still worth trying: the health check runs once a minute, so "offline"
     * can mean "was offline fifty seconds ago".
     */
    public function pickTrainer(): ?Model
    {
        return Model::trainers()
            ->where('is_active', true)
            ->whereNotNull('endpoint_url')
            ->orderByRaw("CASE WHEN status = 'online' THEN 0 ELSE 1 END")
            ->orderBy('id')
            ->first();
    }

    private function fail(string $message, int $status): array
    {
        return ['ok' => false, 'status' => $status, 'message' => $message];
    }

    private function isUnreachableFromOutside(string $callback): bool
    {
        if ($callback === '') return true;

        $host = parse_url($callback, PHP_URL_HOST);

        return in_array($host, ['localhost', '127.0.0.1', '::1', '0.0.0.0'], true);
    }

    /** Guzzle messages carry the whole URL and stack noise; trim them. */
    private function trim(string $message): string
    {
        $message = strtok($message, "\n");

        return strlen($message) > 180 ? substr($message, 0, 180) . '...' : $message;
    }
}
