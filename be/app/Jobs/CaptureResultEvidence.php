<?php

namespace App\Jobs;

use App\Models\AnalysisRecord;
use App\Services\ResultEvidence;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Storage;

/**
 * Renders the thumbnails that outlive a run, on its own.
 *
 * These used to be produced inline, at the end of the interpolation job. That
 * was fine on a development laptop and wrong on the hardware this is heading
 * for: rendering a 16-bit TIFF to PNG is pure PHP and CPU-bound, roughly half
 * a second per 1024x1024 frame here and several times that on a Raspberry Pi.
 * Six frames is ten to fifteen seconds of a single core — spent after the work
 * the researcher actually asked for was already finished, while the GPU sat
 * idle and the next queued job waited behind it.
 *
 * So it is its own job. The interpolation finishes and the researcher is told;
 * the pictures follow a moment later.
 *
 * Failure is quiet and deliberate: a thumbnail that will not render is not
 * worth an error on a job that succeeded.
 */
class CaptureResultEvidence implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * One attempt. A frame that will not decode will not decode on the third
     * try either, and retrying would only spend the same CPU again.
     */
    public int $tries = 1;

    public function __construct(public AnalysisRecord $record) {}

    public function handle(ResultEvidence $evidence): void
    {
        // Retention could in principle have swept the job between the
        // interpolation finishing and this running. There is nothing left to
        // photograph in that case, and nothing worth complaining about.
        if ($this->record->files_deleted_at !== null) {
            return;
        }

        $generated = Storage::files($this->record->output_folder);

        if ($generated === []) {
            return;
        }

        sort($generated);

        $evidence->capture($this->record, $generated);
    }
}
