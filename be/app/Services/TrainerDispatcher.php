<?php

namespace App\Services;

use App\Models\Model;
use App\Models\TrainingJob;
use Illuminate\Http\Client\Response;
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

        $trainerUrl = $this->trainEndpoint($trainerUrl);

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
            // `$trainer` is null when the address came from config or from the
            // job rather than from the registry; there is no secret to send in
            // that case. See WorkerRequest.
            $response = app(WorkerRequest::class)
                ->for($trainer, (int) config('training.dispatch_timeout', 30))
                ->post($trainerUrl, [
                    'job_id' => $job->id,
                    'name' => $job->name,
                    'total_epochs' => $job->total_epochs,
                    // Cast, because a freshly created job does not carry this
                    // attribute at all. `current_epoch` is NOT NULL DEFAULT 0
                    // in the database, but MySQL applies that on insert and
                    // never tells Eloquent: the model `create()` returns holds
                    // only what was passed to it, so reading the column back
                    // gives null until something calls `fresh()`.
                    //
                    // `resume_from_epoch: int = 0` on the trainer is not
                    // Optional, so that null was a 422 on **every** run a
                    // researcher started, while a job that had been
                    // round-tripped through the database went through — which
                    // is exactly why it survived being tested by hand. The
                    // same trap took `verify_tls` a day earlier.
                    'resume_from_epoch' => (int) ($job->current_epoch ?? 0),
                    // An object, never an array. PHP has one array type and
                    // json_encode renders the empty one as `[]`, which Pydantic
                    // refuses for a `dict` field — so a run left at its default
                    // hyperparameters was rejected 422 while a run with even one
                    // of them set went through. Casting settles it at the edge,
                    // where the JSON is made.
                    'hyperparameters' => (object) ($job->hyperparameters ?? []),
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
            return $this->fail(
                "The trainer refused the job (HTTP {$response->status()})."
                    . $this->whyRefused($response),
                502
            );
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

    /**
     * The trainer's own account of why it said no.
     *
     * "The trainer refused the job (HTTP 422)" names a number and throws away
     * the only part that could be acted on. FastAPI answers a validation
     * failure with `{"detail":[{"loc":["body","hyperparameters"],"msg":"Input
     * should be a valid dictionary"}]}` — which says exactly which field and
     * exactly what was wrong with it, and we were discarding it and then
     * guessing. Twice.
     *
     * Kept short and appended rather than replacing the status: the number
     * still separates "refused" from "unreachable", and the sentence says what
     * to change.
     */
    private function whyRefused(Response $response): string
    {
        $detail = $response->json('detail');

        if (is_string($detail) && $detail !== '') {
            return ' ' . $this->trim($detail);
        }

        // The validation-error shape: a list of {loc, msg}.
        if (is_array($detail)) {
            $parts = [];

            foreach ($detail as $item) {
                if (!is_array($item)) {
                    continue;
                }

                $where = is_array($item['loc'] ?? null)
                    // `["body", "hyperparameters"]` reads better as
                    // `body.hyperparameters` than as a printed array.
                    ? implode('.', array_map('strval', $item['loc']))
                    : null;

                $message = $item['msg'] ?? null;

                if ($message === null) {
                    continue;
                }

                $parts[] = $where === null ? $message : "{$where}: {$message}";
            }

            if ($parts !== []) {
                return ' ' . $this->trim(implode('; ', $parts));
            }
        }

        // Not a FastAPI validation error — an ngrok error page, a plain string,
        // an empty body. Whatever it is, the first line of it beats nothing.
        $body = trim((string) $response->body());

        return $body === '' ? '' : ' ' . $this->trim($body);
    }

    /**
     * The address a job is actually POSTed to.
     *
     * The trainer notebook prints its tunnel root and says "register this as
     * the trainer URL", so that is what an administrator pastes. But the route
     * is `POST /train`, and a POST to the root is answered **405** by FastAPI —
     * a refusal that reads like the trainer rejecting the job rather than the
     * platform knocking on the wrong door. Every run sat at `queued`.
     *
     * An inference endpoint is registered with its path (`…/predict`) because
     * that is what the prediction notebook prints, so both conventions are in
     * the registry at once and neither is wrong. Append the path only when
     * none was given, and a URL that already names one is left alone.
     */
    public function trainEndpoint(string $url): string
    {
        $path = parse_url($url, PHP_URL_PATH);

        return in_array(trim((string) $path), ['', '/'], true)
            ? rtrim($url, '/') . '/train'
            : $url;
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
