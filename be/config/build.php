<?php

return [
    // Set by the deployment workflow while Laravel's config cache is built.
    // These values are operational identifiers, never credentials.
    'commit_sha' => env('APP_COMMIT_SHA', 'unknown'),
    'built_at' => env('APP_BUILD_TIME_UTC', 'unknown'),
];
