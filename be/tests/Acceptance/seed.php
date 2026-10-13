<?php

// Generates owned synthetic records only in the explicitly isolated database.
$app = require __DIR__.'/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use App\Models\AiConversation;
use App\Models\AiMessage;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\NewsPost;
use App\Models\User;
use Illuminate\Support\Facades\Storage;

$action = $argv[1] ?? 'seed';
if ($action === 'revoke-admin') {
    User::where('email', 'admin@task6.test')->update(['role' => 'user']);
    exit;
}
if ($action === 'restore-admin') {
    User::where('email', 'admin@task6.test')->update(['role' => 'admin', 'is_active' => true]);
    exit;
}
if ($action === 'revoke-user' || $action === 'restore-user') {
    User::where('email', 'user@task6.test')->update(['is_active' => $action === 'restore-user']);
    exit;
}
if ($action === 'expired-link') {
    echo Illuminate\Support\Facades\URL::temporarySignedRoute('api.downloads.predictions', now()->subMinute(), [
        'id' => AnalysisRecord::where('job_id', 'task6-download')->firstOrFail()->id,
        'kind' => 'results', 'owner' => User::where('email', 'user@task6.test')->firstOrFail()->id,
    ], absolute: false);
    exit;
}
$password = json_decode(file_get_contents('/tmp/task6-accounts.json'), true)['password'];
$users = [];
foreach (['admin' => 'admin', 'user' => 'user', 'other' => 'user'] as $name => $role) {
    $users[$name] = User::updateOrCreate(['email' => $name.'@task6.test'], [
        'name' => 'Task 6 '.$name, 'password' => $password, 'role' => $role,
        'is_active' => true, 'must_change_password' => false,
    ]);
    $chat = AiConversation::firstOrCreate(['user_id' => $users[$name]->id, 'title' => 'Task 6 '.$name.' history']);
    if (!$chat->messages()->exists()) {
        for ($i = 1; $i <= 45; $i++) {
            AiMessage::create(['ai_conversation_id' => $chat->id, 'role' => $i % 2 ? 'user' : 'assistant',
                'content' => "Synthetic message $i. ".str_repeat('Owned CT research history, no patient data. ', 6)]);
        }
    }
}
$model = Model::firstOrCreate(['slug' => 'task6-ct'], [
    'name' => 'Task 6 CPU inference fixture', 'version' => '1.0.0',
    'base_url' => config('model_uploads.internal_url'), 'endpoint' => '/predict/task6-ct/1.0.0',
    'full_endpoint_url' => config('model_uploads.internal_url').'/predict/task6-ct/1.0.0',
    'auth_token' => config('model_uploads.inference_token'), 'is_active' => true, 'worker_active' => true,
    'status' => 'online', 'verify_tls' => true,
]);
$record = AnalysisRecord::firstOrCreate(['job_id' => 'task6-download'], [
    'user_id' => $users['user']->id, 'model_id' => $model->id, 'status' => 'completed',
    'input_files_count' => 2, 'output_files_count' => 1, 'expires_at' => now()->addDay(),
    'processing_time_seconds' => 1,
]);
$record->update(['input_folder' => $record->storageDirectory().'/input', 'output_folder' => $record->storageDirectory().'/output']);
// > Vercel's 4.5 MB function response limit; fresh random payload resists ZIP compression.
if (!Storage::exists($record->output_folder.'/frame_002.tif')) {
    Storage::put($record->output_folder.'/frame_002.tif', random_bytes(6 * 1024 * 1024));
}
Storage::put('task6/news.png', base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO5kAAAAASUVORK5CYII='));
Storage::put('task6/video.webm', 'synthetic-media-bytes');
NewsPost::firstOrCreate(['title' => 'Task 6 synthetic news'], [
    'summary' => 'Isolated acceptance fixture', 'body' => 'Generated local data', 'is_published' => true,
    'published_at' => now(), 'created_by' => $users['admin']->id,
    'image_path' => 'task6/news.png', 'image_mime' => 'image/png',
    'video_path' => 'task6/video.webm', 'video_mime' => 'video/webm', 'video_size_bytes' => 21,
]);
echo json_encode(['record' => $record->id, 'model' => $model->id,
    'sha256' => hash_file('sha256', Storage::path($record->output_folder.'/frame_002.tif')),
    'users' => array_map(fn ($user) => $user->id, $users)]).PHP_EOL;
