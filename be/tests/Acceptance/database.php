<?php

$app = require __DIR__.'/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$config = config('database.connections.mysql');
$pdo = new PDO('mysql:host='.$config['host'].';port='.$config['port'], $config['username'], $config['password']);
$pdo->exec('CREATE DATABASE IF NOT EXISTS db_aict_task6');
foreach (['framework/cache/data', 'framework/sessions', 'framework/views', 'logs', 'app/private', 'app/public'] as $directory) {
    if (!is_dir(storage_path($directory))) {
        mkdir(storage_path($directory), 0700, true);
    }
}
echo 'Disposable acceptance database/storage prepared.'.PHP_EOL;
