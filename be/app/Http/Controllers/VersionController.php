<?php

namespace App\Http\Controllers;

class VersionController extends Controller
{
    public function __invoke()
    {
        $commit = (string) config('build.commit_sha', 'unknown');
        if (! preg_match('/\A[0-9a-f]{40}\z/', $commit)) {
            $commit = 'unknown';
        }

        $builtAt = (string) config('build.built_at', 'unknown');
        if ($builtAt !== 'unknown' && strtotime($builtAt) === false) {
            $builtAt = 'unknown';
        }

        return response()->json([
            'success' => true,
            'data' => [
                'service' => 'deepct-api',
                'environment' => config('app.env'),
                'commit_sha' => $commit,
                'built_at' => $builtAt,
            ],
        ]);
    }
}
