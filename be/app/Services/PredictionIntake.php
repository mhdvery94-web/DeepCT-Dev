<?php

namespace App\Services;

use App\Jobs\ProcessDeepLearningImage;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use App\Models\UserActivity;
use Exception;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use ZipArchive;

/**
 * Turns an uploaded ZIP of frames into a queued prediction job.
 *
 * Shared by both upload paths so they cannot drift apart: the direct
 * `POST /api/predictions` for small files, and the chunked flow used for
 * anything above PHP's `upload_max_filesize`.
 */
class PredictionIntake
{
    /** Per-frame ceiling; a 1024x1024 16-bit TIFF is ~2 MB. */
    private const MAX_FRAME_BYTES = 50 * 1024 * 1024;

    /**
     * @param  string  $absoluteZipPath  a complete ZIP already on local disk
     * @return AnalysisRecord the queued job
     *
     * @throws IntakeException when the archive is unusable
     */
    public function fromZip(
        User $user,
        Model $model,
        string $absoluteZipPath,
        ?string $ipAddress = null,
        ?string $userAgent = null,
        ?string $originalFilename = null
    ): AnalysisRecord {
        $this->assertModelUsable($model);

        $jobId = (string) Str::uuid();
        $inputFolder = "predictions/{$user->id}/{$jobId}/input";

        try {
            $extracted = $this->extract($absoluteZipPath, $inputFolder);

            if ($extracted === 0) {
                throw new IntakeException(
                    'The archive contains no .tif files.',
                    422
                );
            }

            $this->validateFrames($inputFolder);
        } catch (IntakeException $e) {
            Storage::deleteDirectory($inputFolder);
            throw $e;
        } catch (Exception $e) {
            Storage::deleteDirectory($inputFolder);
            throw new IntakeException($e->getMessage(), 422);
        }

        $record = AnalysisRecord::create([
            'user_id' => $user->id,
            'job_id' => $jobId,
            'model_id' => $model->id,
            'file_name' => $originalFilename,
            'input_folder' => $inputFolder,
            'output_folder' => "predictions/{$user->id}/{$jobId}/output",
            'status' => 'pending',
            'input_files_count' => $extracted,
            'expires_at' => now()->addHours(24),
        ]);

        ProcessDeepLearningImage::dispatch($record);

        UserActivity::create([
            'user_id' => $user->id,
            'model_id' => $model->id,
            'activity_type' => 'prediction',
            'description' => "Started prediction with {$extracted} input frame(s)",
            'ip_address' => $ipAddress,
            'user_agent' => $userAgent,
            'metadata' => [
                'job_id' => $jobId,
                'model_name' => $model->name,
                'file_count' => $extracted,
            ],
        ]);

        return $record;
    }

    private function assertModelUsable(Model $model): void
    {
        if (!$model->is_active) {
            throw new IntakeException('The selected model is not active.', 400);
        }

        if ($model->status === 'offline') {
            throw new IntakeException(
                'The selected model is offline. Ask an administrator to check it.',
                503
            );
        }
    }

    /**
     * Extract only the `.tif` entries, flattened into [$destination].
     *
     * Flattening matters: archives are often produced with a wrapping folder,
     * and `Storage::files()` does not recurse, so nested frames would silently
     * disappear from the job.
     */
    private function extract(string $absoluteZipPath, string $destination): int
    {
        $zip = new ZipArchive();

        if ($zip->open($absoluteZipPath) !== true) {
            throw new IntakeException('The file is not a readable ZIP archive.', 422);
        }

        Storage::makeDirectory($destination);
        $extracted = 0;

        for ($i = 0; $i < $zip->numFiles; $i++) {
            $entry = $zip->getNameIndex($i);

            if ($entry === false || str_ends_with($entry, '/')) {
                continue;
            }

            // Skip macOS resource forks and anything hidden.
            if (str_contains($entry, '__MACOSX') || str_starts_with(basename($entry), '.')) {
                continue;
            }

            $extension = strtolower(pathinfo($entry, PATHINFO_EXTENSION));
            if ($extension !== 'tif' && $extension !== 'tiff') {
                continue;
            }

            $stream = $zip->getStream($entry);
            if ($stream === false) {
                continue;
            }

            // basename() also neutralises any `../` path traversal in the entry.
            Storage::put($destination . '/' . basename($entry), $stream);
            fclose($stream);

            $extracted++;
        }

        $zip->close();

        return $extracted;
    }

    /**
     * The job itself rejects gapless sequences, but catching the obvious
     * problems here gives the user an error at upload time rather than after
     * queueing.
     */
    private function validateFrames(string $folder): void
    {
        $files = Storage::files($folder);

        if (count($files) < 2) {
            throw new IntakeException(
                'At least two frames are required to interpolate between.',
                422
            );
        }

        $numbered = 0;

        foreach ($files as $file) {
            if (Storage::size($file) > self::MAX_FRAME_BYTES) {
                throw new IntakeException(
                    'Frame ' . basename($file) . ' exceeds the 50 MB per-file limit.',
                    422
                );
            }

            if (preg_match('/\d/', pathinfo($file, PATHINFO_FILENAME)) === 1) {
                $numbered++;
            }
        }

        if ($numbered < 2) {
            throw new IntakeException(
                'Frame filenames must contain their frame number, for example ' .
                'frame_001.tif and frame_005.tif.',
                422
            );
        }
    }
}
