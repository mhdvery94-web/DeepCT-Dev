<?php

// Local acceptance only: fail closed unless both DB and storage are disposable.
if (getenv('DB_DATABASE') !== 'db_aict_task6' || !getenv('TASK6_STORAGE')) {
    throw new RuntimeException('Use the isolated Task 6 configuration.');
}
require __DIR__.'/../../vendor/autoload.php';
$app = require __DIR__.'/../../bootstrap/app.php';
$app->useStoragePath(getenv('TASK6_STORAGE'));
return $app;
