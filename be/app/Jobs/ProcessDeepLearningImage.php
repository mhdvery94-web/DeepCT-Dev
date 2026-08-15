<?php

namespace App\Jobs;

use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\UserActivity;
use App\Services\Notifier;
use Exception;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * Fills the gaps between uploaded boundary frames by recursive interpolation.
 *
 * The worker is a FastAPI app on Kaggle/Colab behind an ngrok tunnel. Its only
 * route is `POST /predict`, taking **multipart** `file_t0`, `file_t2` and
 * `time_scalar`, and streaming a TIFF back. A handled failure comes back as
 * JSON `{"error": ...}` with HTTP 200, so the status code alone is not enough
 * to tell success from failure.
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
     * Never retry. A retry would redo completed frames and spend GPU time
     * again; a failed job is better inspected than repeated.
     */
    public int $tries = 1;

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
            $indices = array_keys($frames);

            // Fill each gap between consecutive uploaded frames.
            for ($i = 0; $i < count($indices) - 1; $i++) {
                $left = $indices[$i];
                $right = $indices[$i + 1];

                $this->interpolateBetween(
                    $model,
                    $left,
                    $frames[$left],
                    $right,
                    $frames[$right],
                    $generated
                );
            }

            ksort($generated);
            $elapsed = (int) round(microtime(true) - $startTime);

            $this->record->update([
                'status' => 'completed',
                'output_files_count' => count($generated),
                'interpolated_frames' => array_values(
                    array_map(fn($p) => basename($p), $generated)
                ),
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
        } catch (Exception $e) {
            $this->fail_($e->getMessage());
        } finally {
            // Always release the slot, successful or not, or the model's
            // concurrency counter drifts upward and never recovers.
            $model->decrement('current_jobs_count');
        }
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
     * Recursively fill the open interval between two frames.
     *
     * Each generated midpoint becomes a boundary for the two halves around it,
     * which is what makes the interpolation recursive rather than linear.
     *
     * @param array<int, string> $generated collected by reference
     */
    private function interpolateBetween(
        Model $model,
        int $leftIndex,
        string $leftPath,
        int $rightIndex,
        string $rightPath,
        array &$generated
    ): void {
        // Adjacent frames have nothing between them.
        if ($rightIndex - $leftIndex < 2) {
            return;
        }

        $midIndex = intdiv($leftIndex + $rightIndex, 2);
        $midPath = $this->requestMidpoint($model, $leftPath, $rightPath, $midIndex);
        $generated[$midIndex] = $midPath;

        $this->interpolateBetween($model, $leftIndex, $leftPath, $midIndex, $midPath, $generated);
        $this->interpolateBetween($model, $midIndex, $midPath, $rightIndex, $rightPath, $generated);
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
        $response = Http::timeout(self::REQUEST_TIMEOUT_SECONDS)
            ->withoutVerifying() // ngrok / Colab certificates
            ->withHeaders(['ngrok-skip-browser-warning' => 'true'])
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
            ->post($model->endpoint_url, ['time_scalar' => '0.5']);

        if ($response->failed()) {
            throw new Exception(
                "Model returned HTTP {$response->status()} while generating frame {$midIndex}: " .
                $this->summarise($response->body())
            );
        }

        $body = $response->body();
        $contentType = strtolower((string) $response->header('Content-Type'));

        // A handled worker error arrives as JSON with HTTP 200.
        if (str_contains($contentType, 'json') || str_starts_with(ltrim($body), '{')) {
            $decoded = json_decode($body, true);
            $message = $decoded['error'] ?? $decoded['message'] ?? $this->summarise($body);
            throw new Exception("Model rejected frame {$midIndex}: {$message}");
        }

        if ($body === '') {
            throw new Exception("Model returned an empty body for frame {$midIndex}.");
        }

        $outputPath = $this->record->output_folder . '/' .
            $this->outputFilename($leftPath, $midIndex);

        Storage::put($outputPath, $body);

        return $outputPath;
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
