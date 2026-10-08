<?php

// Read-only checks against the restarted API. Tokens are temporary and never
// printed; they are revoked in finally, including when any check fails.
require __DIR__ . '/../vendor/autoload.php';
$app = require __DIR__ . '/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$base = rtrim($argv[1] ?? 'http://127.0.0.1:8000/api', '/');
$checks = 0;
$tokens = [];

try {
    foreach (['admin', 'user'] as $role) {
        $user = App\Models\User::where('role', $role)->where('is_active', true)->where('must_change_password', false)->first();
        if (!$user) throw new RuntimeException("No active account with a changed password for role {$role}.");
        $token = $user->createToken('deployment-smoke', ['*'], now()->addMinutes(2));
        $tokens[] = $token->accessToken;
        $paths = ['/user', '/me/stats', '/me/models', '/me/activities', '/me/training/jobs', '/predictions', '/messages', '/notifications'];
        if ($role === 'admin') $paths = array_merge($paths, ['/admin/stats', '/admin/users', '/admin/models', '/admin/news', '/admin/access-requests', '/admin/conversations', '/admin/activities', '/admin/training/jobs', '/admin/training/datasets', '/admin/queue', '/admin/storage']);
        foreach ($paths as $path) {
            $response = Illuminate\Support\Facades\Http::acceptJson()->withToken($token->plainTextToken)->timeout(30)->get($base . $path);
            if ($response->status() !== 200 || $response->json('success') !== true) throw new RuntimeException("{$role}: GET {$path} returned {$response->status()}.");
            $checks++;
        }
        if ($role === 'user') {
            $response = Illuminate\Support\Facades\Http::acceptJson()->withToken($token->plainTextToken)->timeout(15)->post($base . '/admin/storage/cleanup');
            if ($response->status() !== 403) throw new RuntimeException('Researcher can reach admin cleanup.');
            $checks++;
        }
    }
    $response = Illuminate\Support\Facades\Http::acceptJson()->timeout(15)->get($base . '/news');
    if ($response->status() !== 200) throw new RuntimeException('Public news unavailable.');
    $checks++;
    $first = $response->json('data.0.id');
    if ($first) {
        $article = Illuminate\Support\Facades\Http::acceptJson()->timeout(15)->get($base . '/news/' . $first);
        if ($article->status() !== 200 || !array_key_exists('body', $article->json('data') ?? [])) throw new RuntimeException('Published article body unavailable.');
        $checks++;
    }
    echo "Portal API smoke checks passed: {$checks}.\n";
} catch (Throwable $error) {
    fwrite(STDERR, $error->getMessage() . "\n");
    $failed = true;
} finally {
    foreach ($tokens as $token) $token->delete();
}
exit(isset($failed) ? 1 : 0);
