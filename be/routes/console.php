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
