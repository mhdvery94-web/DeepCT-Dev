<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Schedule: Health check every 5 minutes
Schedule::command('models:health-check')->everyFiveMinutes();

// Schedule: Cleanup expired tokens daily (7-day expiration)
Schedule::command('tokens:cleanup')->daily();

// Schedule: Delete prediction output past its 24-hour retention window.
// Hourly rather than daily so files expire close to their stated deadline
// instead of lingering until the next 02:00.
Schedule::command('predictions:cleanup')->hourly();
