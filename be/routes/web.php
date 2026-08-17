<?php

use App\Http\Controllers\HealthController;
use Illuminate\Support\Facades\Route;

// Neither of these is a closure, and that is deliberate: `route:cache` cannot
// serialise a closure, and without the cache every artisan command rebuilds the
// route table on boot — six times a minute, for the scheduled health check.
// `Route::view` is the cacheable form of "render this template".
Route::view('/', 'welcome');

// Health check. Unauthenticated on purpose: it is what you probe when nothing
// else works.
Route::get('/api/health', HealthController::class);
