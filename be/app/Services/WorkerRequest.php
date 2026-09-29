<?php

namespace App\Services;

use App\Models\Model;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;

/**
 * Builds every outgoing call to a model worker, in one place.
 *
 * There were five: the interpolation job, the health check (twice — single
 * and pooled), the trainer dispatcher, and the admin's test prediction. Each
 * repeated the same two lines by hand. Adding a credential to five call sites
 * means five places to forget it, and the one that gets forgotten is the one
 * that leaks — so they all come through here now.
 *
 * Two things a registered worker gets to decide for itself:
 *
 * - **Its secret.** Sent as `Authorization: Bearer`. Standard, and the header
 *   proxies and log scrubbers already know to redact — which a bespoke
 *   `X-Worker-Token` would sail through in plain text.
 * - **Whether its certificate is checked.** Off by default, matching the
 *   hardcoded `withoutVerifying()` this replaced; a tunnel or a self-signed
 *   LAN certificate needs it off, and a real one should turn it on.
 *
 * The ngrok header stays unconditional. It costs nothing against a worker
 * that is not behind ngrok, and forgetting it against one that is means
 * receiving an HTML interstitial with HTTP 200 where a TIFF was expected.
 */
class WorkerRequest
{
    /**
     * A configured client for [$model], ready to be given a verb.
     *
     * ```php
     * app(WorkerRequest::class)->for($model, 600)->attach(...)->post($url);
     * ```
     *
     * [$model] is nullable because a training run can be dispatched to a URL
     * that belongs to no registered model — `TRAINING_TRAINER_URL`, or an
     * address written onto the job itself. There is no row to read a secret
     * from in that case, so the call goes out as it always did: unverified
     * and unauthenticated. Registering the trainer is what buys it a
     * credential, which is the right incentive.
     */
    public function for(?Model $model, int $timeoutSeconds): PendingRequest
    {
        return $this->configure(Http::timeout($timeoutSeconds), $model);
    }

    /** Configure a server before any of its model rows exist locally. */
    public function forServer(
        ?string $authToken,
        bool $verifyTls,
        int $timeoutSeconds
    ): PendingRequest {
        return $this->configureCredentials(
            Http::timeout($timeoutSeconds),
            $authToken,
            $verifyTls
        );
    }

    /**
     * The same configuration applied to a pooled request.
     *
     * `Http::pool()` hands out its own builder rather than the facade, so the
     * settings have to be applied to that instead of built from scratch.
     */
    public function configure(PendingRequest $request, ?Model $model): PendingRequest
    {
        return $this->configureCredentials(
            $request,
            $model?->auth_token,
            (bool) $model?->verify_tls
        );
    }

    private function configureCredentials(
        PendingRequest $request,
        ?string $authToken,
        bool $verifyTls
    ): PendingRequest
    {
        $request = $request->withHeaders([
            'ngrok-skip-browser-warning' => 'true',
        ]);

        if (! $verifyTls) {
            $request = $request->withoutVerifying();
        }

        return filled($authToken) ? $request->withToken($authToken) : $request;
    }
}
