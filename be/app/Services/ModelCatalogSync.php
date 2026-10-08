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
        bool $verifyTls = true
    ): array {
        $baseUrl = $this->normaliseBaseUrl($baseUrl);
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
            $verifyTls
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
                $seen[] = $slug;

                $model = Model::where('slug', $slug)->first()
                    ?? Model::where('kind', 'inference')
                        ->where('endpoint_url', $fullEndpointUrl)
                        ->first();

                $isNew = $model === null;
                $model ??= new Model();

                $model->fill([
                    'name' => $isNew
                        ? Str::headline(str_replace('-', ' ', $remoteName))
                        : $model->name,
                    'slug' => $slug,
                    'version' => $entry['version'] ?? ($model->version ?: 'remote'),
                    'kind' => 'inference',
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

                if ($isNew) {
                    $model->fill([
                        'is_active' => true,
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

            $missingQuery = Model::inference()->where('base_url', $baseUrl);
            if ($seen !== []) {
                $missingQuery->whereNotIn('slug', $seen);
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
