<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

/**
 * Answers "is anything actually consuming the queue?"
 *
 * The platform needs three processes and only one of them is obvious. Start
 * `octane` alone and an upload succeeds, the job row is written, the screen
 * says "queued" — and then nothing happens, for ever, with no error anywhere
 * because nothing failed. That is the single most confusing state this
 * application can be in, and it is invisible from the inside.
 *
 * There is no API that reports "a worker is running", so this infers it from
 * the queue itself: a job that has been available for longer than
 * [STALL_SECONDS] and has never been reserved means nobody picked it up.
 * Reserved-but-old is a different thing — that is a job being worked on, which
 * is normal, since one interpolation runs for minutes.
 */
class QueueHealth
{
    /**
     * How long an unreserved job may sit before we call the queue stalled.
     *
     * A worker claims a job within milliseconds of it appearing, so anything
     * beyond a minute means there is no worker rather than a slow one.
     */
    public const STALL_SECONDS = 60;

    /**
     * @return array{stalled: bool, waiting: int, oldest_wait_seconds: int}
     */
    public function inspect(): array
    {
        $waiting = DB::table('jobs')->whereNull('reserved_at')->count();

        if ($waiting === 0) {
            return ['stalled' => false, 'waiting' => 0, 'oldest_wait_seconds' => 0];
        }

        // `available_at` is a unix timestamp on the jobs table.
        $oldest = (int) DB::table('jobs')
            ->whereNull('reserved_at')
            ->min('available_at');

        $waited = max(0, time() - $oldest);

        return [
            'stalled' => $waited >= self::STALL_SECONDS,
            'waiting' => $waiting,
            'oldest_wait_seconds' => $waited,
        ];
    }

    /**
     * What to tell someone staring at a job that is not moving.
     *
     * Pass the state in when you already have it. Called bare, this repeats
     * [inspect()] — two more queries against `jobs` for an answer the caller
     * is usually holding already.
     *
     * @param  array{stalled: bool, waiting: int, oldest_wait_seconds: int}|null  $state
     */
    public function message(?array $state = null): ?string
    {
        $state ??= $this->inspect();

        if (!$state['stalled']) {
            return null;
        }

        $minutes = max(1, (int) round($state['oldest_wait_seconds'] / 60));

        return "Nothing has picked this job up for {$minutes} minute(s). "
            . 'The processing worker is probably not running — an administrator '
            . 'needs to start it with `npm run serve:all` in the backend folder.';
    }
}
