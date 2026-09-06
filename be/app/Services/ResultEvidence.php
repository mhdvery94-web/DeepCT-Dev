<?php

namespace App\Services;

use App\Models\AnalysisRecord;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * The small part of a run that outlives the run.
 *
 * Results are deleted 24 hours after they are made — 1.5 GB of TIFFs per job
 * is not something a lab machine can keep — and until now that left a record
 * saying a job had completed with no evidence of what it had produced. A
 * researcher could not look at last week's work at all.
 *
 * So a handful of thumbnails are kept for good. A few hundred kilobytes buys
 * a permanent answer to "what did that run actually look like", which the
 * numbers alone cannot give: an MAE of 40 counts says nothing about whether
 * the model drew a plausible slice or a smear.
 *
 * Stored under `prediction-evidence/` rather than inside the job folder,
 * because `predictions:cleanup` deletes that folder whole. Living outside it
 * is the entire point.
 */
class ResultEvidence
{
    public function __construct(private TiffPreview $tiff) {}

    /** Longest edge. Big enough to judge, small enough to keep for ever. */
    public const THUMBNAIL_SIZE = 256;

    /**
     * How many frames are kept. A run may generate hundreds; keeping all of
     * them would re-create the storage problem retention exists to solve.
     */
    public const MAX_FRAMES = 6;

    public static function directoryFor(AnalysisRecord $record): string
    {
        return "prediction-evidence/{$record->id}";
    }

    /**
     * Render up to [MAX_FRAMES] of the generated frames and keep them.
     *
     * Spread across the run rather than taken from the front: the first six
     * frames of a long sequence all sit next to the same scanned boundary and
     * say little about how the rest went.
     *
     * Best effort by design. A thumbnail that will not render must never cost
     * a researcher the interpolation they waited for.
     *
     * @param array<int, string> $generatedPaths storage paths, in frame order
     * @return array<int, string> the names kept
     */
    public function capture(AnalysisRecord $record, array $generatedPaths): array
    {
        $paths = array_values($generatedPaths);
        $total = count($paths);

        if ($total === 0) {
            return [];
        }

        $chosen = $total <= self::MAX_FRAMES
            ? $paths
            : array_map(
                fn(int $i) => $paths[(int) round($i * ($total - 1) / (self::MAX_FRAMES - 1))],
                range(0, self::MAX_FRAMES - 1)
            );

        $directory = self::directoryFor($record);
        $kept = [];

        foreach (array_unique($chosen) as $path) {
            try {
                $png = $this->tiff->toPng(Storage::get($path), self::THUMBNAIL_SIZE);
                $name = pathinfo($path, PATHINFO_FILENAME) . '.png';

                Storage::put("{$directory}/{$name}", $png);
                $kept[] = $name;
            } catch (Throwable $e) {
                Log::warning('Could not keep evidence thumbnail', [
                    'record' => $record->id,
                    'frame' => basename($path),
                    'reason' => $e->getMessage(),
                ]);
            }
        }

        return $kept;
    }

    /** Names of the thumbnails still on disk for this run. */
    public function listFor(AnalysisRecord $record): array
    {
        $directory = self::directoryFor($record);

        return collect(Storage::files($directory))
            ->map(fn($path) => basename($path))
            ->sort()
            ->values()
            ->all();
    }

    /** Deleting a job should not leave its thumbnails behind for ever. */
    public function forget(AnalysisRecord $record): void
    {
        Storage::deleteDirectory(self::directoryFor($record));
    }
}
