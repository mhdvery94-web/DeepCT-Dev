<?php

namespace App\Jobs;

use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\UserActivity;
use App\Services\FrameMetrics;
use App\Services\Notifier;
use App\Services\WorkerRequest;
use Exception;
use Throwable;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\Jobs\SyncJob;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * Fills the gaps between uploaded boundary frames by recursive interpolation.
 *
 * The worker is a FastAPI app on Kaggle/Colab behind an ngrok tunnel. A model
 * row supplies its own `POST /predict/{model_name}` URL; every route takes the
 * same multipart `file_t0`, `file_t2` and `time_scalar` body and streams a TIFF
 * back. A handled legacy failure may still be JSON with HTTP 200.
 *
 * Interpolation is always at t=0.5 and recursive: given frames 1 and 7, the
 * midpoint 4 is generated first, then 1-4 and 4-7 are filled the same way
 * using the frame just produced. There is no manual time_scalar input.
 */
class ProcessDeepLearningImage implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /** A single GPU round-trip runs ~20s; a large gap needs many of them. */
    public int $timeout = 7200;

    /**
     * Three, but only one of them for the same reason.
     *
     * A model that *answers* and refuses will refuse identically next time, so
     * that is failed on the spot — retrying would redo completed frames and
     * spend GPU time to reach the same rejection.
     *
     * A worker that does not answer at all is a different thing entirely, and
     * it is the thing that happens when the GPU lives on a workstation rather
     * than in a data centre. Workstations sleep. They reboot for updates.
     * Somebody unplugs one to play a game. Failing a researcher's job because
     * a machine was asleep for ninety seconds is not a fault report, it is
     * lost work — so an unreachable worker sends the job back to the queue.
     *
     * @see requeueOrFail()
     */
    public int $tries = 3;

    /**
     * How long to wait before asking an absent worker again. Long enough for
     * a wake-from-sleep or a reboot, short enough that a researcher watching
     * the screen sees it move.
     */
    private const RETRY_DELAY_SECONDS = 120;

    /** Refuse jobs that would take absurdly long rather than hanging for hours. */
    private const MAX_GENERATED_FRAMES = 200;

    /** Per-request budget for one interpolation round-trip. */
    private const REQUEST_TIMEOUT_SECONDS = 180;

    public function __construct(public AnalysisRecord $record) {}

    public function handle(): void
    {
        $startTime = microtime(true);
        $model = $this->record->model;

        if (!$model) {
            $this->fail_('The model for this job no longer exists.');
            return;
        }

        if (!$model->is_active) {
            $this->fail_("Model '{$model->name}' is not active.");
            return;
        }

        $this->record->update(['status' => 'processing', 'time_scalar' => 0.5]);
        $model->increment('current_jobs_count');

        try {
            $frames = $this->readInputFrames();

            if (count($frames) < 2) {
                throw new Exception(
                    'At least two numbered frames are required to interpolate between.'
                );
            }

            $this->assertWorkloadIsSane($frames);

            Storage::makeDirectory($this->record->output_folder);

            $generated = [];
            $provenance = [];
            $indices = array_keys($frames);

            // Fill each gap between consecutive uploaded frames. Generation 0
            // is what "came off the scanner" means: these are the only frames
            // in the job that the model had no hand in.
            for ($i = 0; $i < count($indices) - 1; $i++) {
                $left = $indices[$i];
                $right = $indices[$i + 1];

                $this->interpolateBetween(
                    $model,
                    ['index' => $left, 'path' => $frames[$left], 'generation' => 0],
                    ['index' => $right, 'path' => $frames[$right], 'generation' => 0],
                    $generated,
                    $provenance
                );
            }

            ksort($generated);
            ksort($provenance);

            // After the results, so a measurement that misbehaves cannot cost
            // the researcher the frames they actually asked for.
            $validation = $this->validateOnHeldOutFrame($model, $frames);


            $elapsed = (int) round(microtime(true) - $startTime);

            $this->record->update([
                'status' => 'completed',
                'output_files_count' => count($generated),
                'interpolated_frames' => array_values(
                    array_map(fn($p) => basename($p), $generated)
                ),
                'frame_provenance' => array_values($provenance),
                'validation' => $validation,
                'processing_time_seconds' => $elapsed,
                'processing_time' => $elapsed . 's',
                'expires_at' => now()->addHours(24),
                'error_message' => null,
            ]);

            $model->increment('total_predictions');

            UserActivity::create([
                'user_id' => $this->record->user_id,
                'model_id' => $model->id,
                'activity_type' => 'prediction_completed',
                'description' => 'Generated ' . count($generated) .
                    " frame(s) for job {$this->record->job_id}",
                'metadata' => [
                    'job_id' => $this->record->job_id,
                    'input_files' => count($frames),
                    'output_files' => count($generated),
                    'seconds' => $elapsed,
                ],
            ]);

            // A job runs for minutes and nobody watches the screen that long.
            // Notifier swallows its own failures, so a successful prediction is
            // never marked failed because a notification row would not write.
            Notifier::predictionCompleted($this->record, count($generated));

            // The thumbnails that outlive retention, queued rather than
            // rendered here: six frames is ten to fifteen seconds of a single
            // core on a Raspberry Pi, spent after the work the researcher
            // asked for was already done and while the next job waits.
            CaptureResultEvidence::dispatch($this->record);
        } catch (Exception $e) {
            $this->requeueOrFail($e);
        } finally {
            // Always release the slot, successful or not, or the model's
            // concurrency counter drifts upward and never recovers.
            $model->decrement('current_jobs_count');
        }
    }

    /**
     * Send the job back to the queue when the worker was merely absent, and
     * fail it when the worker had something to say.
     *
     * The distinction is the whole point. "The model rejected frame 4" will be
     * rejected the same way in two minutes; there is nothing to wait for, and
     * repeating it costs GPU time to reach the same answer. "Connection
     * refused" is a machine that is asleep, rebooting, or being used for
     * something else, and in two minutes it may well be back.
     *
     * That case did not exist while the worker lived on Kaggle — a hosted
     * notebook is up or it is gone for the session. It exists now that the GPU
     * is heading for a workstation on the lab network.
     */
    private function requeueOrFail(Exception $e): void
    {
        if (!$this->isWorkerUnreachable($e)) {
            $this->fail_($e->getMessage());

            return;
        }

        // The wording is the same whether or not a retry is possible.
        // `cURL error 7: Failed to connect` is a true sentence and a useless
        // one — it tells a researcher nothing they can act on, and it reads
        // like their upload was at fault.
        if (!$this->canBeRequeued()) {
            $this->fail_(
                'The model is not responding. It may be asleep or restarting — '
                . 'check its status and run the job again.'
            );

            return;
        }

        // Back to `pending`, which is what the researcher's screen already
        // knows how to show. Marking it `failed` and then un-failing it would
        // flicker a red row for no reason.
        $this->record->update([
            'status' => 'pending',
            'error_message' => 'The model is not responding. Waiting and trying again '
                . '(attempt ' . $this->attempts() . ' of ' . $this->tries . ').',
        ]);

        $this->release(self::RETRY_DELAY_SECONDS);
    }

    /**
     * Whether nothing answered, as opposed to something answering badly.
     *
     * Matched on the exception type rather than on words in a message: a
     * `ConnectionException` is Guzzle saying the request never completed —
     * refused, timed out, DNS failure, TLS handshake — while every refusal
     * this job raises itself is a plain `Exception` carrying the worker's own
     * words.
     */
    private function isWorkerUnreachable(Exception $e): bool
    {
        return $e instanceof ConnectionException
            || $e->getPrevious() instanceof ConnectionException;
    }

    /**
     * False on the last attempt, and false when there is no queue to go back
     * to — `sync` runs the job inline, where releasing it would simply lose
     * it.
     */
    private function canBeRequeued(): bool
    {
        return $this->attempts() < $this->tries
            && $this->job !== null
            && !($this->job instanceof SyncJob);
    }

    /**
     * Laravel calls this when the job throws outside our own try/catch, or
     * when it times out. Without it a crashed job sits on `processing`
     * forever.
     */
    public function failed(?\Throwable $e): void
    {
        $this->record->refresh();

        if ($this->record->isProcessing() || $this->record->isPending()) {
            $message = $e?->getMessage() ?? 'The job failed to run.';

            $this->record->update([
                'status' => 'failed',
                'error_message' => $message,
            ]);

            // A timeout or a crash lands here instead of fail_(), and it is
            // the case where the researcher is *most* in the dark.
            Notifier::predictionFailed($this->record, $message);
        }
    }

    // --------------------------------------------------------------- helpers

    /**
     * Uploaded frames keyed and sorted by their frame number.
     *
     * @return array<int, string> frame index => storage path
     */
    private function readInputFrames(): array
    {
        $frames = [];

        foreach (Storage::files($this->record->input_folder) as $path) {
            $index = $this->frameIndex($path);
            if ($index !== null) {
                $frames[$index] = $path;
            }
        }

        ksort($frames);

        return $frames;
    }

    /** Trailing digit run in the filename: `TC-D_0007.tif` -> 7. */
    private function frameIndex(string $path): ?int
    {
        $name = pathinfo($path, PATHINFO_FILENAME);

        if (preg_match('/(\d+)(?!.*\d)/', $name, $m) === 1) {
            return (int) $m[1];
        }

        return null;
    }

    /**
     * A gap of n produces n-1 frames, each costing a GPU round-trip. Reject
     * up front rather than discovering it two hours in.
     */
    private function assertWorkloadIsSane(array $frames): void
    {
        $indices = array_keys($frames);
        $total = 0;

        for ($i = 0; $i < count($indices) - 1; $i++) {
            $total += max(0, $indices[$i + 1] - $indices[$i] - 1);
        }

        if ($total === 0) {
            throw new Exception(
                'The uploaded frames are consecutive, so there is nothing to interpolate. ' .
                'Leave a gap between frame numbers (for example 001 and 007).'
            );
        }

        if ($total > self::MAX_GENERATED_FRAMES) {
            throw new Exception(
                "This job would generate {$total} frames, above the limit of " .
                self::MAX_GENERATED_FRAMES . '. Split the sequence into smaller uploads.'
            );
        }
    }

    /**
     * The closest-together `[a, mid, b]` among the uploaded frames where `mid`
     * is the exact midpoint of `a` and `b`, or null when there is none.
     *
     * Closest-together matters. Any qualifying triple can be measured, but a
     * wide one measures something harder: drawing the midpoint of frames 51
     * and 69 spans nine frames of movement, while 51 and 55 span two — and the
     * two-frame case is what this platform actually asks the model to do.
     * Reporting the harder number would understate the model on the work it is
     * really being given.
     *
     * @param array<int, int> $indices uploaded frame numbers, ascending
     * @return array{0:int, 1:int, 2:int}|null
     */
    private function tightestHoldOut(array $indices): ?array
    {
        $present = array_flip($indices);
        $best = null;

        foreach ($indices as $left) {
            foreach ($indices as $right) {
                // Even spans only: the model interpolates the midpoint, and an
                // odd span has none.
                if ($right - $left < 2 || ($right - $left) % 2 !== 0) {
                    continue;
                }

                $middle = intdiv($left + $right, 2);

                if (!isset($present[$middle])) {
                    continue;
                }

                if ($best === null || ($right - $left) < ($best[2] - $best[0])) {
                    $best = [$left, $middle, $right];
                }
            }
        }

        return $best;
    }

    /**
     * Recursively fill the open interval between two frames.
     *
     * Each generated midpoint becomes a boundary for the two halves around it,
     * which is what makes the interpolation recursive rather than linear.
     *
     * **And that is why provenance is recorded here.** A midpoint drawn
     * between two scanned frames is the model's output. A midpoint drawn
     * between a scanned frame and one the model produced a moment ago is the
     * model's output *fed its own output* — whatever error the first frame
     * carried is now an input. The deeper the recursion, the more times that
     * has happened, and a reader of the results has no other way to know it.
     *
     * `generation` counts exactly that: 1 means both boundaries were scanned,
     * 2 means at least one boundary was itself generated, and so on.
     *
     * @param array{index:int, path:string, generation:int} $left
     * @param array{index:int, path:string, generation:int} $right
     * @param array<int, string> $generated  collected by reference
     * @param array<int, array<string, mixed>> $provenance collected by reference
     */
    private function interpolateBetween(
        Model $model,
        array $left,
        array $right,
        array &$generated,
        array &$provenance
    ): void {
        // Adjacent frames have nothing between them.
        if ($right['index'] - $left['index'] < 2) {
            return;
        }

        $midIndex = intdiv($left['index'] + $right['index'], 2);
        $midPath = $this->requestMidpoint($model, $left['path'], $right['path'], $midIndex);

        $mid = [
            'index' => $midIndex,
            'path' => $midPath,
            'generation' => 1 + max($left['generation'], $right['generation']),
        ];

        $generated[$midIndex] = $midPath;
        $provenance[$midIndex] = [
            'frame' => basename($midPath),
            'index' => $midIndex,
            'from' => [$left['index'], $right['index']],
            'generation' => $mid['generation'],
            // How many of the two boundaries the model had invented itself.
            // `generation` already implies it, but a reader scanning a table
            // should not have to derive it.
            'synthetic_parents' =>
                ($left['generation'] > 0 ? 1 : 0) + ($right['generation'] > 0 ? 1 : 0),
        ];

        $this->interpolateBetween($model, $left, $mid, $generated, $provenance);
        $this->interpolateBetween($model, $mid, $right, $generated, $provenance);
    }

    /**
     * One round-trip to the worker; returns the storage path it was saved to.
     */
    private function requestMidpoint(
        Model $model,
        string $leftPath,
        string $rightPath,
        int $midIndex
    ): string {
        $body = $this->requestFrame($model, $leftPath, $rightPath, "frame {$midIndex}");

        $outputPath = $this->record->output_folder . '/' .
            $this->outputFilename($leftPath, $midIndex);

        Storage::put($outputPath, $body);

        return $outputPath;
    }

    /**
     * The round-trip itself, returning the TIFF bytes without writing them.
     *
     * Split out from [requestMidpoint] because the hold-out check needs a
     * generated frame it can measure and then throw away — writing it into the
     * output folder would put a frame the archive already contained into the
     * researcher's results.
     *
     * [$label] only ever appears in error messages, and exists so a failure
     * during validation does not read as a failure to produce a result frame.
     */
    private function requestFrame(
        Model $model,
        string $leftPath,
        string $rightPath,
        string $label
    ): string {
        $response = app(WorkerRequest::class)
            ->for($model, self::REQUEST_TIMEOUT_SECONDS)
            ->attach(
                'file_t0',
                Storage::get($leftPath),
                basename($leftPath),
                ['Content-Type' => 'image/tiff']
            )
            ->attach(
                'file_t2',
                Storage::get($rightPath),
                basename($rightPath),
                ['Content-Type' => 'image/tiff']
            )
            ->post($model->predictionUrl(), ['time_scalar' => '0.5']);

        if ($response->failed()) {
            $detail = $this->summarise($response->body());
            $message = match ($response->status()) {
                404 => "Model {$model->slug} was not found while generating {$label}.",
                422 => "Model rejected the input for {$label}: {$detail}",
                500 => "Model could not be loaded or inference failed for {$label}: {$detail}",
                default => "Model returned HTTP {$response->status()} while generating {$label}: {$detail}",
            };

            throw new Exception($message);
        }

        $body = $response->body();
        $contentType = strtolower((string) $response->header('Content-Type'));

        // A handled worker error arrives as JSON with HTTP 200.
        if (str_contains($contentType, 'json') || str_starts_with(ltrim($body), '{')) {
            $decoded = json_decode($body, true);
            $message = $decoded['error'] ?? $decoded['message'] ?? $this->summarise($body);
            throw new Exception("Model rejected {$label}: {$message}");
        }

        if (! str_contains($contentType, 'image/tiff')) {
            throw new Exception(
                "Model returned unexpected content type '{$contentType}' for {$label}."
            );
        }

        if ($body === '') {
            throw new Exception("Model returned an empty body for {$label}.");
        }

        return $body;
    }

    /**
     * Regenerate a frame the archive already had, and measure the result
     * against it.
     *
     * This is the only ground truth available. The frames a researcher wants
     * filled are, by definition, ones nobody has — so the check holds out one
     * they *do* have: an uploaded frame that sits exactly halfway between two
     * other uploaded frames is set aside, drawn again from that pair, and
     * compared with what was really there.
     *
     * **The rule used to be narrower, and it was the wrong rule.** It demanded
     * three *consecutive* frames — 1, 2, 3 — which sounds like the same thing
     * and is not. A researcher uploads frames *with gaps*; that is the entire
     * product. The first real archive to reach this code held frames 51, 53,
     * 55 … 69, every other one, and offered no consecutive triplet anywhere —
     * so nothing was measured, on an archive where 53 is the exact midpoint of
     * 51 and 55 and could have been checked immediately.
     *
     * Any even span will do, because the model always interpolates the
     * midpoint: for uploaded frames `a` and `b` where `(a + b)` is even and
     * `(a + b) / 2` is also uploaded, that middle frame can be held out. The
     * old consecutive case is simply this one with `b - a = 2`.
     *
     * The **narrowest** span available is used. Frames 51 and 55 are two
     * interpolations apart in the real run; 51 and 69 are nine, and a midpoint
     * drawn across nine frames of movement measures the model on a problem
     * harder than the one it was asked to solve.
     *
     * Costs one extra round-trip, and returns null when the archive offers no
     * such triple at all — which is still an ordinary case rather than a
     * failure. Frames 1, 3 and 7 have no midpoint among them. Every failure
     * here is swallowed into a note rather than thrown: a measurement that
     * could not be taken must never cost a researcher the interpolation they
     * waited for.
     *
     * @param array<int, string> $frames uploaded frames, keyed by index
     * @return array<string, mixed>|null
     */
    private function validateOnHeldOutFrame(Model $model, array $frames): ?array
    {
        $triple = $this->tightestHoldOut(array_keys($frames));

        if ($triple !== null) {
            [$left, $middle, $right] = $triple;

            try {
                $bytes = $this->requestFrame(
                    $model,
                    $frames[$left],
                    $frames[$right],
                    "hold-out frame {$middle}"
                );

                $metrics = app(FrameMetrics::class)->compare(
                    Storage::get($frames[$middle]),
                    $bytes
                );

                return $metrics + [
                    'held_out_frame' => basename($frames[$middle]),
                    'index' => $middle,
                    'from' => [$left, $right],
                ];
            } catch (Throwable $e) {
                // A measurement that could not be taken is worth saying so
                // about. Losing a completed interpolation over it is not.
                return ['error' => $this->summarise($e->getMessage())];
            }
        }

        return null;
    }

    /**
     * Name the generated frame after its neighbours, preserving the prefix and
     * zero padding: `frame_001.tif` at index 4 becomes `frame_004.tif`.
     */
    private function outputFilename(string $neighbourPath, int $index): string
    {
        $name = pathinfo($neighbourPath, PATHINFO_FILENAME);
        $extension = pathinfo($neighbourPath, PATHINFO_EXTENSION) ?: 'tif';

        if (preg_match('/^(.*?)(\d+)(\D*)$/', $name, $m) === 1) {
            $padded = str_pad((string) $index, strlen($m[2]), '0', STR_PAD_LEFT);
            return "{$m[1]}{$padded}{$m[3]}.{$extension}";
        }

        return "frame_{$index}.{$extension}";
    }

    private function summarise(string $body): string
    {
        $clean = trim(preg_replace('/\s+/', ' ', strip_tags($body)) ?? '');

        return mb_strimwidth($clean, 0, 200, '...');
    }

    /** Record a failure on the job and mirror it into the log. */
    private function fail_(string $message): void
    {
        Log::warning("Prediction job {$this->record->job_id} failed: {$message}");

        $this->record->update([
            'status' => 'failed',
            'error_message' => $message,
        ]);

        UserActivity::create([
            'user_id' => $this->record->user_id,
            'model_id' => $this->record->model_id,
            'activity_type' => 'prediction_failed',
            'description' => "Prediction {$this->record->job_id} failed",
            'metadata' => [
                'job_id' => $this->record->job_id,
                'error' => $message,
            ],
        ]);

        Notifier::predictionFailed($this->record, $message);
    }
}
