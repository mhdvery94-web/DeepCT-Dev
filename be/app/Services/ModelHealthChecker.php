<?php

namespace App\Services;

use App\Models\Model;
use App\Services\Notifier;
use Illuminate\Support\Facades\Http;

/**
 * Determines whether a remotely deployed inference model is reachable.
 *
 * The models run as FastAPI apps on Kaggle / Google Colab, exposed through an
 * ngrok tunnel. Their only route is `POST /predict`, which requires a
 * multipart body (`file_t0`, `file_t2`, `time_scalar`).
 *
 * We therefore probe with a cheap GET instead of posting a fake body:
 *
 *  - Posting `{"health_check": true}` made FastAPI reply **422 Unprocessable
 *    Entity** (missing required fields). The old code treated any non-2xx as
 *    "offline", so a perfectly healthy server was permanently reported offline.
 *  - A 422/405 response actually *proves* the app is alive: only a running
 *    FastAPI instance can validate a request and reject it.
 *
 * The probe targets the tunnel root rather than `/predict` so we never risk
 * triggering a real GPU inference.
 */
class ModelHealthChecker
{
    /** Requests slower than this are reported as `trouble`. */
    public const SLOW_THRESHOLD_MS = 5000;

    /**
     * Hard timeout for the probe.
     *
     * Must stay under the ten-second schedule interval, or a probe against a
     * dead tunnel would still be running when the next one is due. Eight
     * seconds costs nothing in accuracy: anything past [SLOW_THRESHOLD_MS] is
     * already reported as `trouble`, so the extra seconds only ever confirmed
     * a verdict that had been reached at five.
     */
    public const TIMEOUT_SECONDS = 8;

    /**
     * Probe the model endpoint and persist the resulting status.
     *
     * @return array{status:string, response_time_ms?:float, error?:string}
     */
    public function check(Model $model): array
    {
        if (empty($model->endpoint_url)) {
            return $this->persist($model, 'offline', null, 'Endpoint URL is not set');
        }

        $probeUrl = $this->probeUrl($model->endpoint_url);

        try {
            $startTime = microtime(true);

            $response = Http::timeout(self::TIMEOUT_SECONDS)
                ->withoutVerifying() // ngrok/Colab certificates
                ->withHeaders(['ngrok-skip-browser-warning' => 'true'])
                ->get($probeUrl);

            $responseTime = round((microtime(true) - $startTime) * 1000, 2);

            $status = $response->status();

            // The ngrok edge answers even when nothing is listening behind it.
            // ERR_NGROK_3200 = tunnel offline / agent disconnected.
            $ngrokError = $response->header('ngrok-error-code');
            if (! empty($ngrokError)) {
                return $this->persist(
                    $model,
                    'offline',
                    $responseTime,
                    "Tunnel is not running ({$ngrokError})"
                );
            }

            // Any HTTP status served by the app itself means the process is up.
            // 404 on the root path is expected: FastAPI only defines /predict.
            if (! $this->isServedByApp($status)) {
                return $this->persist(
                    $model,
                    'offline',
                    $responseTime,
                    "Endpoint unreachable (HTTP {$status})"
                );
            }

            if ($responseTime > self::SLOW_THRESHOLD_MS) {
                return $this->persist(
                    $model,
                    'trouble',
                    $responseTime,
                    "Slow response: {$responseTime}ms"
                );
            }

            return $this->persist($model, 'online', $responseTime, null);
        } catch (\Throwable $e) {
            // Connection refused, DNS failure or timeout: nothing is listening.
            return $this->persist($model, 'offline', null, $this->cleanMessage($e->getMessage()));
        }
    }

    /**
     * Reduce a prediction URL to the tunnel root so the probe never triggers
     * an inference run. `https://x.ngrok-free.dev/predict` -> `https://x.ngrok-free.dev/`
     */
    public function probeUrl(string $endpointUrl): string
    {
        $parts = parse_url($endpointUrl);

        if ($parts === false || empty($parts['host'])) {
            return $endpointUrl;
        }

        $scheme = $parts['scheme'] ?? 'https';
        $port = isset($parts['port']) ? ':' . $parts['port'] : '';

        return "{$scheme}://{$parts['host']}{$port}/";
    }

    /**
     * True when the HTTP status was produced by the application itself.
     *
     * 2xx  - fine.
     * 404  - FastAPI is up but the root path is not registered (expected).
     * 405  - route exists but the method differs (e.g. GET on a POST route).
     * 422  - the app parsed and validated our request; it is definitely alive.
     * 5xx  - the app is reachable but failing, so it is not healthy.
     */
    private function isServedByApp(int $status): bool
    {
        return in_array($status, [200, 201, 204, 404, 405, 422], true);
    }

    /**
     * Persist the outcome and return it in the shape callers expect.
     *
     * @return array{status:string, response_time_ms?:float, error?:string}
     */
    private function persist(
        Model $model,
        string $status,
        ?float $responseTime,
        ?string $error
    ): array {
        $previous = $model->status;

        $model->update([
            'status' => $status,
            'last_health_check' => now(),
            'health_check_error' => $error,
        ]);

        // Only on a *transition*. This runs every ten seconds, so a model that
        // is down overnight would otherwise produce 8,640 identical
        // notifications in a day.
        if ($previous !== $status) {
            if ($status === 'offline') {
                Notifier::modelWentOffline($model, $error);
            } elseif ($previous === 'offline' && $status === 'online') {
                Notifier::modelBackOnline($model);
            }
        }

        $result = ['status' => $status];

        if ($responseTime !== null) {
            $result['response_time_ms'] = $responseTime;
        }

        if ($error !== null) {
            $result['error'] = $error;
        }

        return $result;
    }

    /** Guzzle messages include the full URL and stack noise; trim them. */
    private function cleanMessage(string $message): string
    {
        $message = strtok($message, "\n");

        return strlen($message) > 200 ? substr($message, 0, 200) . '...' : $message;
    }
}
