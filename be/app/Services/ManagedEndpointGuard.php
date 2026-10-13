<?php

namespace App\Services;

use App\Models\Model;

/** Keep manual legacy rows out of the configured immutable worker namespace. */
class ManagedEndpointGuard
{
    private function canonical(?string $url): ?array
    {
        $parts = $url ? parse_url($url) : false;
        if (! $parts || ! isset($parts['scheme'], $parts['host'])) {
            return null;
        }
        $scheme = strtolower($parts['scheme']);
        $port = $parts['port'] ?? ($scheme === 'https' ? 443 : 80);
        $segments = [];
        foreach (explode('/', rawurldecode($parts['path'] ?? '')) as $segment) {
            if ($segment === '..') {
                array_pop($segments);
            } elseif ($segment !== '' && $segment !== '.') {
                $segments[] = $segment;
            }
        }

        return [$scheme.'://'.strtolower($parts['host']).':'.$port, '/'.implode('/', $segments)];
    }

    public function assertManualTarget(string $url, bool $catalog = false): void
    {
        $target = $this->canonical($url);
        foreach (['internal_url', 'public_url'] as $key) {
            $base = $this->canonical(config('model_uploads.'.$key));
            if (! $base || $target[0] !== $base[0]) {
                continue;
            }
            $prefix = rtrim($base[1], '/');
            $inside = $target[1] === $prefix || str_starts_with($target[1], $prefix.'/');
            $reserved = $prefix !== '' ? $inside : ($catalog || preg_match('~^/(?:predict/[^/]+/[^/]+(?:/|$)|models(?:/|$)|management(?:/|$)|uploads(?:/|$))~', $target[1]));
            abort_if($reserved, 422, 'Use configured managed model controls for this worker namespace.');
        }
        foreach (Model::whereNotNull('managed_model_id')->get() as $model) {
            abort_if(in_array($target, $this->identities($model), true), 422, 'Managed endpoints cannot be registered through legacy controls.');
        }
    }

    private function identities(Model $model): array
    {
        $urls = [$model->predictionUrl(), $model->endpoint_url];
        foreach (['internal_url', 'public_url'] as $key) {
            if ($base = config('model_uploads.'.$key)) {
                $urls[] = rtrim($base, '/').'/predict/'.$model->managed_model_id.'/'.$model->version;
            }
        }

        return array_filter(array_map(fn ($url) => $this->canonical($url), $urls));
    }

    public function assertNoAliases(Model $model): void
    {
        $identities = $this->identities($model);
        foreach (Model::where('id', '!=', $model->id)->get() as $other) {
            abort_if(in_array($this->canonical($other->predictionUrl()), $identities, true)
                || in_array($this->canonical($other->endpoint_url), $identities, true),
                409, 'An existing registry alias targets this immutable version; availability changes require operator reconciliation.');
        }
    }
}
