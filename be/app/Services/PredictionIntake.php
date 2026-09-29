<?php

namespace App\Services;

use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use App\Models\UserActivity;
use Exception;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use ZipArchive;

/**
 * Turns an uploaded ZIP of frames into a prediction ready for review.
 *
 * Shared by both upload paths so they cannot drift apart: the direct
 * `POST /api/predictions` for small files, and the chunked flow used for
 * anything above PHP's `upload_max_filesize`.
 */
class PredictionIntake
{
    /** Per-frame ceiling; a 1024x1024 16-bit TIFF is ~2 MB. */
    private const MAX_FRAME_BYTES = 50 * 1024 * 1024;

    /** The ZIP limit also applies to its expanded contents. */
    private const MAX_EXTRACTED_BYTES = 2 * 1024 * 1024 * 1024;

    private const MAX_INPUT_FRAMES = 1000;

    /**
     * @param  string  $absoluteZipPath  a complete ZIP already on local disk
     * @return AnalysisRecord the uploaded job awaiting START
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

        // The chunked path refuses on the declared size before anything
        // travels; this one only learns the size when the archive is already
        // on disk, so it checks here — still before extraction, which is where
        // the archive stops being one file and becomes many.
        $refusal = app(StorageGuard::class)->refusalFor(
            (int) (@filesize($absoluteZipPath) ?: 0)
        );

        if ($refusal !== null) {
            throw new IntakeException($refusal, 507);
        }

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
            // Not `pending`: the files are here, but nobody has said to run
            // them yet. POST /predictions/{id}/start does that.
            'status' => 'uploaded',
            'input_files_count' => $extracted,
            'expires_at' => now()->addHours(24),
        ]);

        UserActivity::create([
            'user_id' => $user->id,
            'model_id' => $model->id,
            'activity_type' => 'prediction',
            'description' => "Uploaded {$extracted} input frame(s)",
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

        try {
            $entries = [];
            $names = [];
            $expandedBytes = 0;

            // Read the central directory before writing any extracted bytes.
            // A small compressed archive may expand far beyond the room that
            // the upload-size check reserved.
            for ($i = 0; $i < $zip->numFiles; $i++) {
                $entry = $zip->getNameIndex($i);

                if ($entry === false || str_ends_with($entry, '/')) {
                    continue;
                }

                $filename = basename($entry);
                if (str_contains($entry, '__MACOSX') || str_starts_with($filename, '.')) {
                    continue;
                }

                $extension = strtolower(pathinfo($entry, PATHINFO_EXTENSION));
                if ($extension !== 'tif' && $extension !== 'tiff') {
                    continue;
                }

                $stat = $zip->statIndex($i);
                $size = $stat['size'] ?? null;
                if (!is_int($size) || $size < 0 || $size > self::MAX_FRAME_BYTES) {
                    throw new IntakeException("Frame {$filename} exceeds the 50 MB per-file limit.", 422);
                }

                // Flattening folders must not silently replace a scanned frame.
                $flatName = strtolower($filename);
                if (isset($names[$flatName])) {
                    throw new IntakeException("The archive contains more than one frame named {$filename}.", 422);
                }
                $names[$flatName] = true;

                $expandedBytes += $size;
                if ($expandedBytes > self::MAX_EXTRACTED_BYTES) {
                    throw new IntakeException('The extracted frames exceed the 2 GB archive limit.', 422);
                }

                $entries[] = [$entry, $filename, $size];
                if (count($entries) > self::MAX_INPUT_FRAMES) {
                    throw new IntakeException('The archive contains more than 1000 frames.', 422);
                }
            }

            $refusal = app(StorageGuard::class)->refusalFor(
                max((int) filesize($absoluteZipPath), $expandedBytes)
            );
            if ($refusal !== null) {
                throw new IntakeException($refusal, 507);
            }

            Storage::makeDirectory($destination);

            foreach ($entries as [$entry, $filename, $expectedSize]) {
                $source = $zip->getStream($entry);
                if ($source === false) {
                    throw new IntakeException("Could not read frame {$filename} from the archive.", 422);
                }

                $target = fopen(Storage::path("{$destination}/{$filename}"), 'wb');
                if ($target === false) {
                    fclose($source);
                    throw new IntakeException("Could not store frame {$filename}.", 500);
                }

                try {
                    // The second limit checks bytes actually produced, even
                    // when the ZIP directory reports a smaller size.
                    $written = stream_copy_to_stream($source, $target, self::MAX_FRAME_BYTES + 1);
                } finally {
                    fclose($source);
                    fclose($target);
                }

                if ($written === false || $written !== $expectedSize) {
                    throw new IntakeException("Frame {$filename} is corrupt or exceeds its declared size.", 422);
                }
            }

            return count($entries);
        } finally {
            $zip->close();
        }
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
