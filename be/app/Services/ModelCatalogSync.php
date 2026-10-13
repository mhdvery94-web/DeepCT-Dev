<?php

namespace App\Services;

use App\Models\Model;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

/** Synchronise inference models exposed by one FastAPI multi-model server. */
class ModelCatalogSync
{
    private const TIMEOUT_SECONDS = 15;

    public function __construct(
        private readonly WorkerRequest $workerRequest,
    ) {
    }

    /**
     * @return array{created:int,updated:int,missing:int,models:array<int,Model>}
     */
    public function sync(
        string $baseUrl,
        ?string $authToken = null,
        bool $verifyTls = true,
        bool $managed = false
    ): array {
        $baseUrl = $this->normaliseBaseUrl($baseUrl);
        if (! $managed) {
            app(ManagedEndpointGuard::class)->assertManualTarget($baseUrl, true);
        }
        // Only reconcile barriers that existed before this catalog request.
        // A stale response must not acknowledge a newer availability change.
        $transitions = $managed ? Model::where('base_url', $baseUrl)->get()->mapWithKeys(
            fn (Model $model) => [$model->id => $model->availability_transition]
        )->all() : [];
        $client = $this->workerRequest
            ->forServer($authToken, $verifyTls, self::TIMEOUT_SECONDS)
            ->acceptJson();

        try {
            // The root is the server health endpoint. Checking it separately
            // distinguishes a missing catalogue route from a dead tunnel.
            $health = $client->get($baseUrl . '/');
            $this->assertServerResponse($health->status(), $health->header('ngrok-error-code'));

            $response = $client->get($baseUrl . '/models');
        } catch (ConnectionException $e) {
            throw new RuntimeException($this->connectionMessage($e), previous: $e);
        }

        if ($response->failed()) {
            throw new RuntimeException(
                "AI model catalogue returned HTTP {$response->status()}."
            );
        }

        $payload = $response->json();
        if (! is_array($payload) || ! is_array($payload['models'] ?? null)) {
            throw new RuntimeException('AI model catalogue returned an invalid JSON shape.');
        }

        return DB::transaction(function () use (
            $payload,
            $baseUrl,
            $authToken,
            $verifyTls,
            $managed,
            $transitions
        ): array {
            $created = 0;
            $updated = 0;
            $seen = [];
            $models = [];

            foreach ($payload['models'] as $entry) {
                if (! is_array($entry)) {
                    throw new RuntimeException('AI model catalogue contains a non-object entry.');
                }

                $remoteName = trim((string) ($entry['name'] ?? ''));
                $remoteEndpoint = trim((string) ($entry['endpoint'] ?? ''));
                $slug = Str::slug($remoteName);

                if ($slug === '' || $remoteEndpoint === '') {
                    throw new RuntimeException('Every catalogue model needs a name and endpoint.');
                }

                $endpoint = $this->normaliseEndpoint($remoteEndpoint, $baseUrl);
                $fullEndpointUrl = $baseUrl . $endpoint;
                if (! $managed) {
                    app(ManagedEndpointGuard::class)->assertManualTarget($fullEndpointUrl);
                }

                $identity = $entry['model_id'] ?? null;
                if ($identity !== null) {
                    if (! $managed || ! preg_match('/^[a-z0-9]+(?:-[a-z0-9]+)*$/D', $identity)
                        || ! preg_match('/^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$/D', $entry['version'] ?? '')
                        || ! preg_match('/^[0-9a-f]{64}$/D', $entry['sha256'] ?? '')
                        || $endpoint !== '/predict/'.$identity.'/'.$entry['version']) {
                        throw new RuntimeException('Managed catalogue identity requires configured synchronization.');
                    }
                    $model = Model::where('managed_model_id', $identity)->where('version', $entry['version'])->lockForUpdate()->first();
                    if ($model && ($model->weight_sha256 !== $entry['sha256'] || $model->base_url !== $baseUrl)) {
                        throw new RuntimeException('Managed immutable identity changed.');
                    }
                    if ($model && $model->is_active && ! ($entry['active'] ?? false)) {
                        app(ModelAdmission::class)->assertIdle($model);
                    }
                } else {
                    $model = Model::whereNull('managed_model_id')->where(function ($query) use ($slug, $fullEndpointUrl) {
                        $query->where('slug', $slug)->orWhere('endpoint_url', $fullEndpointUrl);
                    })->lockForUpdate()->first();
                }

                $isNew = $model === null;
                $model ??= new Model();
                if ($identity) {
                    // The immutable tuple owns identity; a legacy row can
                    // already own the remote machine slug. Keep both rows.
                    $slug = $model->slug ?: $slug;
                    $candidate = $slug;
                    $suffix = 1;
                    while (Model::where('slug', $slug)->when($model->exists, fn ($query) => $query->where('id', '!=', $model->id))->exists()) {
                        $slug = $candidate.'-managed-'.$suffix++;
                    }
                }
                $seen[] = $slug;

                $model->fill([
                    'name' => $isNew
                        ? ($identity ? ($entry['display_name'] ?? $remoteName) : Str::headline(str_replace('-', ' ', $remoteName)))
                        : $model->name,
                    'slug' => $slug,
                    'version' => $entry['version'] ?? ($model->version ?: 'remote'),
                    'base_url' => $baseUrl,
                    'endpoint' => $endpoint,
                    'full_endpoint_url' => $fullEndpointUrl,
                    // Kept in lockstep during the compatibility window.
                    'endpoint_url' => $fullEndpointUrl,
                    'model_file' => isset($entry['file'])
                        ? (string) $entry['file']
                        : $model->model_file,
                    'worker_active' => (bool) ($entry['active'] ?? false),
                    'status' => 'online',
                    'last_health_check' => now(),
                    'health_check_error' => null,
                    'health_check_reason' => null,
                    'synced_at' => now(),
                ]);

                if ($identity) {
                    $transition = $model->availability_transition;
                    if ($transition && ($transitions[$model->id]['id'] ?? null) === $transition['id']
                        && is_bool($entry['active'] ?? null) && $entry['active'] === $transition['target_active']) {
                        $model->availability_transition = null;
                    }
                    $model->fill(['managed_model_id' => $identity, 'weight_sha256' => $entry['sha256'],
                        'is_active' => ! $model->availability_transition && (bool) ($entry['active'] ?? false)]);
                    if ($isNew) {
                        $model->description = $entry['description'] ?? '';
                    }
                }

                if ($isNew) {
                    $model->fill([
                        'is_active' => $identity ? (bool) ($entry['active'] ?? false) : true,
                        'current_jobs_count' => 0,
                        'total_predictions' => 0,
                        'deployed_at' => now(),
                        'auth_token' => $authToken,
                        'verify_tls' => $verifyTls,
                    ]);
                }

                $model->save();
                $isNew ? $created++ : $updated++;
                $models[] = $model->fresh();
            }

            $missingQuery = Model::query()->where('base_url', $baseUrl);
            if ($seen !== []) {
                $missingQuery->whereNotIn('slug', $seen);
            }

            foreach ((clone $missingQuery)->lockForUpdate()->get() as $missingModel) {
                app(ModelAdmission::class)->assertIdle($missingModel);
            }
            $missing = $missingQuery->update([
                'status' => 'offline',
                'worker_active' => false,
                'last_health_check' => now(),
                'health_check_error' => 'Model is absent from the AI server catalogue.',
                'health_check_reason' => ModelHealthChecker::REASON_MODEL_MISSING,
                'synced_at' => now(),
            ]);

            return compact('created', 'updated', 'missing', 'models');
        });
    }

    private function normaliseBaseUrl(string $baseUrl): string
    {
        $baseUrl = rtrim(trim($baseUrl), '/');
        $parts = parse_url($baseUrl);

        if ($parts === false || ! in_array($parts['scheme'] ?? null, ['http', 'https'], true)
            || empty($parts['host']) || ! empty($parts['path'])) {
            throw new RuntimeException('AI model server base URL must contain only scheme and host.');
        }

        return $baseUrl;
    }

    private function normaliseEndpoint(string $endpoint, string $baseUrl): string
    {
        if (filter_var($endpoint, FILTER_VALIDATE_URL)) {
            if (! str_starts_with($endpoint, $baseUrl . '/')) {
                throw new RuntimeException('A catalogue endpoint points outside its AI model server.');
            }
            $endpoint = substr($endpoint, strlen($baseUrl));
        }

        if (! str_starts_with($endpoint, '/') || str_starts_with($endpoint, '//')) {
            throw new RuntimeException('A catalogue endpoint must be an absolute path.');
        }

        return $endpoint;
    }

    private function assertServerResponse(int $status, ?string $ngrokError): void
    {
        if (filled($ngrokError)) {
            throw new RuntimeException("AI model server tunnel is offline ({$ngrokError}).");
        }

        if ($status < 200 || $status >= 300) {
            throw new RuntimeException("AI model server health check returned HTTP {$status}.");
        }
    }

    private function connectionMessage(ConnectionException $e): string
    {
        $message = strtolower($e->getMessage());

        return str_contains($message, 'timed out') || str_contains($message, 'curl error 28')
            ? 'AI model server health check timed out.'
            : 'AI model server could not be reached.';
    }
}
