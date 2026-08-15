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
