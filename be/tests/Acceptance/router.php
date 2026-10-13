<?php

define('LARAVEL_START', microtime(true));
$app = require __DIR__.'/app.php';
$app->handleRequest(Illuminate\Http\Request::capture());
