<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "This script is CLI-only.\n");
    exit(1);
}

$path = $argv[1] ?? null;
if (! is_string($path) || ! is_file($path) || basename($path) !== '.env') {
    fwrite(STDERR, "A valid staging .env path is required.\n");
    exit(1);
}

$contents = file_get_contents($path);
if (! is_string($contents)
    || ! preg_match('/^APP_ENV=(["\']?)staging\1\s*$/m', $contents)
    || ! preg_match('/^DB_DATABASE=(["\']?)deepct_staging\1\s*$/m', $contents)) {
    fwrite(STDERR, "Refusing to modify a non-staging environment.\n");
    exit(1);
}

$apiKey = getenv('STAGING_GEMINI_API_KEY');
if (! is_string($apiKey) || ! preg_match('/\A[A-Za-z0-9._-]+\z/', $apiKey)) {
    fwrite(STDERR, "STAGING_GEMINI_API_KEY is unavailable or malformed.\n");
    exit(1);
}

$updates = [
    'GEMINI_API_KEY' => $apiKey,
    'AI_ASSISTANT_ENABLED' => 'true',
    'AI_ASSISTANT_RELEASE_APPROVED' => 'true',
    'AI_METADATA_MODE' => 'true',
    'AI_ASSISTANT_PROVIDER' => 'gemini',
    'AI_GEMINI_MODEL' => 'gemini-2.5-flash-lite',
    'AI_GEMINI_TIMEOUT' => '30',
];

foreach ($updates as $name => $value) {
    $line = $name.'='.$value;
    $pattern = '/^'.preg_quote($name, '/').'=.*$/m';
    if (preg_match($pattern, $contents)) {
        $contents = preg_replace($pattern, $line, $contents, 1);
    } else {
        $contents = rtrim($contents)."\n".$line."\n";
    }
}

$directory = dirname($path);
$temporary = tempnam($directory, '.env-gemini-');
if ($temporary === false
    || file_put_contents($temporary, $contents, LOCK_EX) === false
    || ! chmod($temporary, 0600)
    || ! rename($temporary, $path)) {
    if (is_string($temporary) && is_file($temporary)) {
        @unlink($temporary);
    }
    fwrite(STDERR, "Unable to update the staging environment atomically.\n");
    exit(1);
}

fwrite(STDOUT, "Staging Gemini configuration updated.\n");
