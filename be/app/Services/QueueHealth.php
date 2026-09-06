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

        // A reserved job is a worker with its hands full, and that is the
        // ordinary state of a busy queue rather than a broken one. Without
        // this check a single worker part-way through a two-minute
        // interpolation made every job behind it look abandoned, and the
        // platform told researchers nothing had picked their work up while it
        // was in fact working through their backlog. Crying wolf here is worse
        // than saying nothing: the one time the message is true, it has
        // already been taught to be ignored.
        //
        // Not proof of life for ever — a worker killed mid-job leaves its row
        // reserved, which is what `--timeout` and `queue:retry` exist for. It
        // is proof that *something claimed work*, which is the question being
        // asked here.
        $busy = DB::table('jobs')->whereNotNull('reserved_at')->exists();

        return [
            'stalled' => !$busy && $waited >= self::STALL_SECONDS,
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

    /**
     * The same fact, for someone who cannot act on it.
     *
     * [message()] names a command and a folder, which is exactly right for the
     * administrator who has to type it and exactly wrong on a researcher's
     * screen: it reads as an error they caused, in a vocabulary they have no
     * use for, sitting above work they cannot get on with.
     *
     * The fact itself still has to be said. Silence here would put a researcher
     * back where this class exists to rescue them from — watching a clock icon
     * that is never going to change. So the wait is reported, the cause is
     * named as something on our side, and the instruction is not.
     *
     * @param  array{stalled: bool, waiting: int, oldest_wait_seconds: int}|null  $state
     */
    public function researcherMessage(?array $state = null): ?string
    {
        $state ??= $this->inspect();

        if (!$state['stalled']) {
            return null;
        }

        $minutes = max(1, (int) round($state['oldest_wait_seconds'] / 60));

        return "Processing has not started after {$minutes} minute(s). "
            . 'This is a problem on the platform rather than with your upload. '
            . 'Your frames are safe, and the run continues on its own once '
            . 'processing resumes.';
    }
}
