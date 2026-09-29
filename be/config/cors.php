<?php

return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_methods' => ['*'],
    'allowed_origins' => ['*'],
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    // The web client must see the digest before it can accept a download.
    'exposed_headers' => ['X-Checksum-MD5', 'Content-MD5'],
    'max_age' => 0,
    'supports_credentials' => false,
];
