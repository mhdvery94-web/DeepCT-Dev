<?php

namespace App\Services;

use App\Models\AnalysisRecord;
use Illuminate\Support\Collection;

/**
 * Who is on the queue right now, in the order the worker will reach them.
 *
 * WHY NOT THE ACTIVITY LOG
 * ------------------------
 * The obvious source looks like `user_activities`, and it is the wrong one.
 * That is an audit trail: it records events that *happened* — "started an
 * analysis" — with nothing to say whether the run is still going. Answering
 * "who is using the model" from it means finding events with no matching
 * completion, which is inference, and inference is the guesswork this exists
 * to remove.
 *
 * `analysis_records` states it outright. `status` is `processing` for a run the
 * worker has in hand and `pending` for one waiting, and the row already carries
 * `user_id`, `model_id`, `input_files_count` and `created_at`. Nothing has to
 * be derived and nothing can drift out of step with reality, because this *is*
 * the reality the worker acts on.
 *
 * ONE DEFINITION OF THE QUEUE
 * ---------------------------
 * The ordering here is the same one a researcher sees as their own position,
 * because it is computed in the same place. Two implementations of "what
 * position is this job in" would disagree the first time either changed, and
 * the disagreement would surface as one person's screen contradicting the
 * administrator's.
 */
class QueueBoard
{
    /**
     * How many recent runs the estimate averages over.
     *
     * Enough to smooth a single slow run, few enough that a GPU swap or a
     * Kaggle session that came back slower shows up the same day rather than
     * being averaged away by months of history.
     */
    private const SAMPLE_SIZE = 20;

    /** Used only before any run has been timed. */
    private const NO_HISTORY_FALLBACK = 5;

    /**
     * Average minutes a single run takes, floored at 1 and capped at 60.
     *
     * `processing_time_seconds` is written when a run finishes and already
     * excludes the queue wait, so nothing extra has to be recorded for this.
     * Measuring from `created_at` instead would fold the wait into the cost of
     * the work and make every estimate grow with the queue it describes.
     */
    public function minutesPerJob(): int
    {
        $seconds = AnalysisRecord::where('status', 'completed')
            ->where('processing_time_seconds', '>', 0)
            ->latest('updated_at')
            ->limit(self::SAMPLE_SIZE)
            ->avg('processing_time_seconds');

        if (!$seconds) {
            return self::NO_HISTORY_FALLBACK;
        }

        return max(1, min(60, (int) ceil($seconds / 60)));
    }

    /**
     * Every waiting job's place in line, keyed by record id.
     *
     * Everyone's jobs, not one account's: a position counted within your own
     * uploads would say "1" while five other people were ahead of you.
     *
     * @return array<int, int>
     */
    public function positions(): array
    {
        $places = [];
        $place = 0;

        foreach (
            AnalysisRecord::where('status', 'pending')
                ->orderBy('created_at')
                // Two uploads finalised in the same second is ordinary, and
                // `created_at` alone leaves their order to whatever the
                // database happens to return. `id` is the tie-break because
                // it is the order they were actually accepted in.
                ->orderBy('id')
                ->pluck('id') as $id
        ) {
            $places[$id] = ++$place;
        }

        return $places;
    }

    /**
     * Where one record sits in that same line, or null if it is not in it.
     *
     * The single-record question used to be answered by counting the rows
     * before a record — `created_at <` plus one — which agrees with the
     * ordering above right up until two records share a timestamp, and then
     * hands both of them the same place. A chunked upload assembles in well
     * under a second, so the tie is not exotic; it showed up as a researcher
     * reading "1" off their history while the administrator's board had them
     * second.
     *
     * Null rather than a number for anything not waiting. `uploaded` files are
     * sitting on disk until someone presses START and `processing` is already
     * out of the queue, so a position for either would be an invention.
     */
    public function positionOf(AnalysisRecord $record): ?int
    {
        return $this->positions()[$record->id] ?? null;
    }

    /**
     * The board an administrator reads: running first, then the line.
     *
     * Running jobs are not given a position. They are not waiting for anything
     * — numbering them alongside the queue would suggest they are still in it.
     *
     * @return array{
     *     running: array<int, array<string, mixed>>,
     *     waiting: array<int, array<string, mixed>>,
     *     minutes_per_job: int,
     *     busy: int,
     *     queued: int,
     * }
     */
    public function board(): array
    {
        $records = AnalysisRecord::whereIn('status', ['processing', 'pending'])
            // Eager-loaded, or a queue of thirty costs sixty extra queries.
            ->with(['user:id,name,email', 'model:id,name,version'])
            ->orderBy('created_at')
            ->orderBy('id')
            ->get();

        $perJob = $this->minutesPerJob();
        $positions = $this->positions();

        $running = $this->rowsFor($records, 'processing', $positions, $perJob);
        $waiting = $this->rowsFor($records, 'pending', $positions, $perJob);

        return [
            'running' => $running,
            'waiting' => $waiting,
            'minutes_per_job' => $perJob,
            'busy' => count($running),
            'queued' => count($waiting),
        ];
    }

    /**
     * @param  Collection<int, AnalysisRecord>  $records
     * @param  array<int, int>  $positions
     * @return array<int, array<string, mixed>>
     */
    private function rowsFor(
        Collection $records,
        string $status,
        array $positions,
        int $perJob
    ): array {
        return $records
            ->where('status', $status)
            ->map(fn (AnalysisRecord $r) => $this->row($r, $positions, $perJob))
            ->values()
            ->all();
    }

    /**
     * @param  array<int, int>  $positions
     * @return array<string, mixed>
     */
    private function row(AnalysisRecord $record, array $positions, int $perJob): array
    {
        $place = $positions[$record->id] ?? null;
        $elapsed = max(0, now()->diffInSeconds($record->created_at, absolute: true));

        return [
            'id' => $record->id,
            'job_id' => $record->job_id,
            'status' => $record->status,

            // The whole point of the screen. `user_id` cascades, so an
            // ownerless queued row cannot actually occur — the null branch is
            // here because the column permits it, not because anything is
            // known to produce it.
            'user' => $record->user ? [
                'id' => $record->user->id,
                'name' => $record->user->name,
                'email' => $record->user->email,
            ] : null,

            // `model_id` is `set null`, so this one genuinely happens: a model
            // deregistered while its work is still queued.
            'model' => $record->model ? [
                'id' => $record->model->id,
                'name' => $record->model->name,
                'version' => $record->model->version,
            ] : null,

            'input_files_count' => $record->input_files_count,

            // For a waiting job this is how long it has waited; for a running
            // one, how long it has been running. Same clock, and the status
            // beside it says which question it answers.
            'elapsed_seconds' => $elapsed,

            'queue_position' => $place,
            'estimated_wait_minutes' => $place === null ? null : $place * $perJob,

            'created_at' => $record->created_at?->toIso8601String(),
        ];
    }
}
