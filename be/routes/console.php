<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Model availability, checked once a minute.
//
// It ran every ten seconds, and that cadence was the single most expensive
// thing on the machine. Each run is a fresh `php artisan` process — roughly
// 600 ms of CPU even with the route cache — so six of them a minute cost about
// 6% of a core continuously, and they landed on top of Octane, MySQL and the
// queue worker. A login that should take 500 ms was measured at 5.7 s when it
// collided with one.
//
// A minute is not a downgrade in practice. This drives a status light that
// answers "is it worth starting an upload?", and nobody can tell ten seconds
// of staleness from sixty. What *does* need to be immediate is the moment
// someone is about to upload — and that is a button now, not a cadence:
// `POST /api/me/models/refresh` probes on demand.
//
// `withoutOverlapping` still matters: a probe against a dead tunnel can take
// seconds. The two-minute expiry means a crashed run releases the lock by
// itself instead of freezing the schedule until someone clears the cache.
Schedule::command('models:health-check')
    ->everyMinute()
    ->withoutOverlapping(2);

// Schedule: Cleanup expired tokens daily (7-day expiration)
Schedule::command('tokens:cleanup')->daily();

// Schedule: Delete prediction output past its 24-hour retention window.
// Hourly rather than daily so files expire close to their stated deadline
// instead of lingering until the next 02:00.
Schedule::command('predictions:cleanup')->hourly();

// Hand back training jobs whose worker stopped reporting.
//
// Every five minutes rather than every ten seconds: the window it enforces is
// fifteen minutes, and reclaiming a job the moment it goes quiet would steal
// work from a GPU that is merely busy with a long epoch.
Schedule::command('training:reclaim')->everyFiveMinutes()->withoutOverlapping(5);

// Keep the training queue moving.
//
// A run used to be dispatched once, when it was created, and never again — so
// a failed attempt left it at `queued` for ever while the screen showed it a
// position in a line that could not advance. This sends the oldest waiting run
// whenever the trainer is free.
//
// Every minute, and `withoutOverlapping`: dispatch posts a dataset URL and
// waits on a tunnel, so a slow trainer must not have a second copy of this
// stacking up behind it.
Schedule::command('training:dispatch-queued')
    ->everyMinute()
    ->withoutOverlapping(5);

// Free training dataset archives nobody has come back to.
//
// Daily, not hourly: the window is measured in weeks, and a sweep that walks
// every archive is not something to run sixty times a day for a deadline
// nothing crosses that often. 03:10 keeps it clear of the 03:00 crowd.
Schedule::command('training:cleanup')->dailyAt('03:10');
