<?php

namespace App\Services;

use App\Models\Model;
use App\Models\ModelUpload;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

/** Only configured worker identities and credentials enter this control plane. */
class ModelUploads
{
    public function configuration(): array
    {
        $config = config('model_uploads');
        foreach (['internal_url', 'public_url', 'management_token', 'inference_token'] as $key) {
            abort_unless(is_string($config[$key]) && $config[$key] !== '', 503, 'Model upload service is not configured.');
        }
        foreach (['internal_url', 'public_url'] as $key) {
            $parts = parse_url($config[$key]);
            abort_unless($parts && isset($parts['host']) && ! isset($parts['user'], $parts['pass'])
                && ! isset($parts['query']) && ! isset($parts['fragment'])
                && in_array($parts['scheme'] ?? '', $key === 'public_url' ? ['https'] : ['http', 'https']), 503, 'Invalid worker configuration.');
            abort_if($key === 'internal_url' && ! empty($parts['path']) && $parts['path'] !== '/', 503, 'Internal worker URL must be root-only.');
        }
        abort_if(hash_equals($config['management_token'], $config['inference_token']), 503, 'Worker credentials must differ.');

        return $config;
    }

    public function request(string $method, string $path, array $body = []): array
    {
        $config = $this->configuration();
        try {
            $response = Http::withToken($config['management_token'])->acceptJson()->timeout(15)
                ->withOptions(['allow_redirects' => false])->send($method, rtrim($config['internal_url'], '/').$path, ['json' => $body]);
        } catch (ConnectionException $e) {
            abort(503, 'Model upload worker unavailable; reconcile status before retrying.');
        }
        abort_unless($response->successful(), in_array($response->status(), [401, 404, 409, 413, 422, 503, 507]) ? $response->status() : 502,
            'Model upload operation rejected; reconcile session status.');
        $data = $response->json();
        abort_unless(is_array($data) && Str::isUuid($data['id'] ?? ''), 502, 'Invalid worker response.');

        return $data;
    }

    public function present(ModelUpload $upload, array $data): array
    {
        abort_unless(($data['id'] ?? null) === $upload->tuf_id && ($data['manifest'] ?? null) == $upload->manifest, 502, 'Worker session identity mismatch.');
        $upload->update(['state' => $data['state']]);
        $safe = array_intersect_key($data, array_flip(['manifest', 'offset', 'state', 'published', 'compatibility', 'expires_at', 'token', 'operation', 'last_error']));

        return $safe + ['id' => $upload->id, 'upload_url' => rtrim($this->configuration()['public_url'], '/').'/uploads/'.$upload->tuf_id];
    }

    public function synchronize(): array
    {
        $config = $this->configuration();

        return app(ModelCatalogSync::class)->sync($config['internal_url'], $config['inference_token'], true, true);
    }

    public function action(ModelUpload $upload, string $action): array
    {
        if (in_array($action, ['activate', 'deactivate'])) {
            DB::transaction(function () use ($upload, $action) {
                $model = Model::where('managed_model_id', $upload->manifest['model_id'])
                    ->where('version', $upload->manifest['version'])->lockForUpdate()->firstOrFail();
                abort_if($model->availability_transition, 409, 'Availability is reconciling; synchronize before another change.');
                app(ModelAdmission::class)->assertIdle($model);
                app(ManagedEndpointGuard::class)->assertNoAliases($model);
                $this->configuration();
                // Commit before the remote call. A lost response cannot roll
                // this admission barrier back while a delayed mutation runs.
                $model->update(['is_active' => false, 'availability_transition' => [
                    'id' => (string) Str::uuid(), 'target_active' => $action === 'activate',
                ]]);
            });
        }
        $data = $this->request('POST', '/management/uploads/'.$upload->tuf_id.'/'.$action);
        $safe = $this->present($upload, $data);
        if (in_array($action, ['publish', 'activate', 'deactivate'])) {
            $this->synchronize();
        }

        return $safe;
    }
}
