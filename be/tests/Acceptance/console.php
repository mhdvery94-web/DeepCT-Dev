<?php

define('LARAVEL_START', microtime(true));
$app = require __DIR__.'/app.php';
exit($app->handleCommand(new Symfony\Component\Console\Input\ArgvInput));
