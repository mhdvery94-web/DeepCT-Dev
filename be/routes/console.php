<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Model availability, checked every ten seconds.
//
// Five minutes was too coarse to be useful: the Kaggle session behind the
// model expires on its own, and a researcher would start an upload against a
// model that had been dead for four minutes. Ten seconds is close enough to
// live that the console can show availability as a status light.
//
// `withoutOverlapping` matters at this cadence — a probe against a dead tunnel
// can take seconds, and without the lock the runs would pile up on each other.
// The two-minute expiry means a crashed run releases the lock by itself
// instead of freezing the schedule until someone clears the cache.
Schedule::command('models:health-check')
    ->everyTenSeconds()
    ->withoutOverlapping(2);

// Schedule: Cleanup expired tokens daily (7-day expiration)
Schedule::command('tokens:cleanup')->daily();

// Schedule: Delete prediction output past its 24-hour retention window.
// Hourly rather than daily so files expire close to their stated deadline
// instead of lingering until the next 02:00.
Schedule::command('predictions:cleanup')->hourly();
