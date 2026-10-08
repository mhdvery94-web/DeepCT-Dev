<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\NewsPost;
use App\Services\IntakeException;
use App\Services\PredictionIntake;
use App\Services\QueueBoard;
use App\Services\StorageGuard;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Resumable, chunked ZIP upload.
 *
 * A real frame sequence runs to hundreds of megabytes, and pushing that
 * through a single request is fragile: a dropped connection means starting
 * over, and progress cannot be reported meaningfully.
 *
 * Note that PHP's own `upload_max_filesize` mostly does not bite under Octane,
 * because RoadRunner parses the multipart body itself — a 4 MB direct upload
 * succeeds against a 2 MB limit. This flow exists for resumability and honest
 * progress, and so the app keeps working behind nginx + PHP-FPM where those
 * limits *do* apply. [chunkSize()] adapts to whichever server is in front.
 *
 * Sequence:
 *
 *   POST   /api/predictions/uploads             -> { upload_id, chunk_size }
 *   PATCH  /api/predictions/uploads/{id}        -> append one chunk, repeat
 *   POST   /api/predictions/uploads/{id}/finalize -> queue the prediction
 *   DELETE /api/predictions/uploads/{id}        -> abandon
 *
 * State lives beside the partial file rather than in the cache, so an
 * interrupted upload can be resumed after a server restart: `GET` on the
 * session reports how many bytes already landed.
 */
class PredictionUploadController extends Controller
{
    /** Preferred chunk size, subject to what PHP will actually accept. */
    private const PREFERRED_CHUNK_SIZE = 4 * 1024 * 1024;

    /** Floor, so a badly configured server still makes progress. */
    private const MIN_CHUNK_SIZE = 256 * 1024;

    /** Hard ceiling on a single upload. */
    private const MAX_TOTAL_BYTES = 2 * 1024 * 1024 * 1024;

    public function __construct(private readonly PredictionIntake $intake) {}

    /** POST /api/predictions/uploads */
    public function start(Request $request)
    {
        $validated = $request->validate([
            'purpose' => 'nullable|in:prediction,news_video',
            'model_id' => 'required_unless:purpose,news_video|exclude_if:purpose,news_video|exists:models,id',
            'total_size' => [
                'required',
                'integer',
                'min:1',
                // Refused before a single byte travels, rather than after
                // fifty megabytes do.
                'max:' . ($request->input('purpose') === 'news_video'
                    ? NewsPost::MAX_VIDEO_BYTES
                    : self::MAX_TOTAL_BYTES),
            ],
            'filename' => 'nullable|string|max:255',
            // News video only.
            'news_post_id' => 'required_if:purpose,news_video|nullable|exists:news_posts,id',
        ]);

        $purpose = $validated['purpose'] ?? 'prediction';
        $model = null;

        // The route is open to every signed-in user, because uploading a
        // prediction is a researcher's job. Attaching a video to a research
        // post is not, so the role check lives here rather than on the route.
        if ($purpose === 'news_video' && $request->user()->role !== 'admin') {
            return $this->error('Only an administrator may attach a video to a post.', 403);
        }

        if ($purpose === 'prediction') {
            $model = Model::findOrFail($validated['model_id']);

            // Fail before the user spends minutes uploading into a dead endpoint.
            if (!$model->is_active) {
                return $this->error('The selected model is not active.', 400);
            }
            if ($model->status === 'offline') {
                return $this->error(
                    'The selected model is offline. Ask an administrator to check it.',
                    503
                );
            }
        }

        // Before a single byte travels. The declared size is known here, and
        // refusing now costs a round trip; refusing after fifty megabytes have
        // arrived costs the upload, and refusing *never* costs the machine.
        $refusal = app(StorageGuard::class)->refusalFor((int) $validated['total_size']);

        if ($refusal !== null) {
            // 507, not 400: nothing is wrong with the request. The server has
            // nowhere to put it, and a client should not retry with a smaller
            // file and expect a different answer.
            return $this->error($refusal, 507);
        }

        $uploadId = (string) Str::uuid();

        $this->writeMeta($request->user()->id, $uploadId, [
            'upload_id' => $uploadId,
            'user_id' => $request->user()->id,
            'purpose' => $purpose,
            'model_id' => $model?->id,
            'news_post_id' => $validated['news_post_id'] ?? null,
            'filename' => $validated['filename'] ?? 'upload.zip',
            'total_size' => (int) $validated['total_size'],
            'received' => 0,
            'created_at' => now()->toIso8601String(),
        ]);

        Storage::put($this->partPath($request->user()->id, $uploadId), '');

        return response()->json([
            'success' => true,
            'data' => [
                'upload_id' => $uploadId,
                'chunk_size' => $this->chunkSize(),
                'received' => 0,
                'total_size' => (int) $validated['total_size'],
            ],
        ], 201);
    }

    /** GET /api/predictions/uploads/{uploadId} — resume support. */
    public function status(Request $request, string $uploadId)
    {
        $meta = $this->readMeta($request->user()->id, $uploadId);

        return response()->json([
            'success' => true,
            'data' => [
                'upload_id' => $uploadId,
                'received' => $meta['received'],
                'total_size' => $meta['total_size'],
                'chunk_size' => $this->chunkSize(),
                'complete' => $meta['received'] >= $meta['total_size'],
            ],
        ]);
    }

    /**
     * PATCH /api/predictions/uploads/{uploadId}
     *
     * Chunks must arrive in order. `offset` is required and checked so a
     * retried or duplicated request cannot silently corrupt the archive.
     */
    public function chunk(Request $request, string $uploadId)
    {
        $request->validate([
            'offset' => 'required|integer|min:0',
            'chunk' => 'required|file',
        ]);

        $userId = $request->user()->id;
        $meta = $this->readMeta($userId, $uploadId);
        $offset = (int) $request->input('offset');

        // Idempotent retry: the client is re-sending a chunk we already have.
        if ($offset < $meta['received']) {
            return response()->json([
                'success' => true,
                'message' => 'Chunk already received.',
                'data' => ['received' => $meta['received'], 'total_size' => $meta['total_size']],
            ]);
        }

        if ($offset !== $meta['received']) {
            return $this->error(
                "Out-of-order chunk: expected offset {$meta['received']}, got {$offset}.",
                409
            );
        }

        $incoming = $request->file('chunk');
        $size = $incoming->getSize() ?? 0;

        if ($meta['received'] + $size > $meta['total_size']) {
            return $this->error('This chunk would exceed the declared total size.', 422);
        }

        $absolutePath = Storage::path($this->partPath($userId, $uploadId));
        $handle = fopen($absolutePath, 'ab');

        if ($handle === false) {
            return $this->error('Could not open the upload for writing.', 500);
        }

        // Stream the chunk in rather than reading it whole into memory.
        $source = fopen($incoming->getRealPath(), 'rb');
        stream_copy_to_stream($source, $handle);
        fclose($source);
        fclose($handle);

        $meta['received'] += $size;
        $this->writeMeta($userId, $uploadId, $meta);

        return response()->json([
            'success' => true,
            'data' => [
                'received' => $meta['received'],
                'total_size' => $meta['total_size'],
                'complete' => $meta['received'] >= $meta['total_size'],
            ],
        ]);
    }

    /** POST /api/predictions/uploads/{uploadId}/finalize */
    public function finalize(Request $request, string $uploadId)
    {
        $userId = $request->user()->id;
        $meta = $this->readMeta($userId, $uploadId);

        $partPath = $this->partPath($userId, $uploadId);
        $actual = Storage::exists($partPath) ? Storage::size($partPath) : 0;

        if ($actual !== $meta['total_size']) {
            return $this->error(
                "Upload is incomplete: {$actual} of {$meta['total_size']} bytes received.",
                409
            );
        }

        if (!in_array($meta['purpose'] ?? 'prediction', ['prediction', 'news_video'], true)) {
            $this->discard($userId, $uploadId);
            return $this->error('This upload purpose is no longer supported.', 410);
        }

        if (($meta['purpose'] ?? 'prediction') === 'news_video') {
            return $this->finalizeNewsVideo($request, $uploadId, $meta, $partPath);
        }

        $model = Model::find($meta['model_id']);
        if (!$model) {
            $this->discard($userId, $uploadId);
            return $this->error('The selected model no longer exists.', 404);
        }

        try {
            $record = $this->intake->fromZip(
                $request->user(),
                $model,
                Storage::path($partPath),
                $request->ip(),
                $request->userAgent(),
                $meta['filename']
            );
        } catch (IntakeException $e) {
            $this->discard($userId, $uploadId);
            return $this->error($e->getMessage(), $e->status());
        } finally {
            // The assembled archive is never needed again either way.
            $this->discard($userId, $uploadId);
        }

        return response()->json([
            'success' => true,
            'message' => 'Prediction queued.',
            'data' => [
                'id' => $record->id,
                'job_id' => $record->job_id,
                'status' => $record->status,
                'input_files_count' => $record->input_files_count,
                'queue_position' => $this->queuePosition($record),
                'expires_at' => $record->expires_at->toIso8601String(),
                'created_at' => $record->created_at->toIso8601String(),
            ],
        ], 201);
    }

    /** DELETE /api/predictions/uploads/{uploadId} */
    public function abort(Request $request, string $uploadId)
    {
        $this->readMeta($request->user()->id, $uploadId); // 404s if not ours
        $this->discard($request->user()->id, $uploadId);

        return response()->json(['success' => true, 'message' => 'Upload discarded.']);
    }

    // --------------------------------------------------------------- helpers

    /**
     * Largest chunk this PHP install will actually accept.
     *
     * Advertising a fixed size is a trap: on a stock Windows php.ini
     * `upload_max_filesize` is 2M, so a 4 MB chunk is rejected before the
     * application ever sees it and the upload dies with a confusing error.
     * The client reads this value from the session response, so raising the
     * ini settings is enough to speed uploads up — no client change needed.
     */
    private function chunkSize(): int
    {
        $limits = array_filter([
            $this->iniBytes('upload_max_filesize'),
            $this->iniBytes('post_max_size'),
        ]);

        $ceiling = $limits === [] ? self::PREFERRED_CHUNK_SIZE : min($limits);

        // Leave room for the multipart envelope and the other form fields.
        $usable = (int) ($ceiling * 0.8);

        return max(
            self::MIN_CHUNK_SIZE,
            min(self::PREFERRED_CHUNK_SIZE, $usable)
        );
    }

    /** Convert a php.ini shorthand size ("2M", "8M", "512K") to bytes. */
    private function iniBytes(string $key): ?int
    {
        $raw = trim((string) ini_get($key));

        if ($raw === '' || $raw === '-1') {
            return null; // Unlimited or unset.
        }

        $value = (int) $raw;

        return match (strtolower(substr($raw, -1))) {
            'g' => $value * 1024 * 1024 * 1024,
            'm' => $value * 1024 * 1024,
            'k' => $value * 1024,
            default => $value,
        };
    }

    private function partPath(int $userId, string $uploadId): string
    {
        return "temp/uploads/{$userId}/{$uploadId}.part";
    }

    private function metaPath(int $userId, string $uploadId): string
    {
        return "temp/uploads/{$userId}/{$uploadId}.json";
    }

    /**
     * Reading through a user-scoped path is what enforces ownership: another
     * account's upload id simply does not resolve.
     */
    private function readMeta(int $userId, string $uploadId): array
    {
        $path = $this->metaPath($userId, $uploadId);

        abort_unless(Storage::exists($path), 404, 'Upload session not found.');

        return json_decode(Storage::get($path), true) ?: [];
    }

    private function writeMeta(int $userId, string $uploadId, array $meta): void
    {
        Storage::put($this->metaPath($userId, $uploadId), json_encode($meta));
    }

    private function discard(int $userId, string $uploadId): void
    {
        Storage::delete([
            $this->partPath($userId, $uploadId),
            $this->metaPath($userId, $uploadId),
        ]);
    }

    /**
     * Attach a finished upload to a news post.
     *
     * The type is read from the assembled bytes rather than the filename or
     * anything the client claimed, for the same reason `validatePayload()`
     * uses `mimetypes:` instead of `mimes:` for the photo: an extension is a
     * suggestion, and this machine cannot re-encode anything that turns out
     * to be something else.
     */
    private function finalizeNewsVideo(Request $request, string $uploadId, array $meta, string $partPath)
    {
        $userId = $request->user()->id;

        // Checked again here, not only at start(): the two calls are separate
        // requests and a role can change between them.
        if ($request->user()->role !== 'admin') {
            $this->discard($userId, $uploadId);
            return $this->error('Only an administrator may attach a video to a post.', 403);
        }

        $post = NewsPost::find($meta['news_post_id'] ?? null);

        if (!$post) {
            $this->discard($userId, $uploadId);
            return $this->error('That post no longer exists.', 404);
        }

        $mime = mime_content_type(Storage::path($partPath)) ?: 'application/octet-stream';

        if (!in_array($mime, NewsPost::VIDEO_MIMES, true)) {
            $this->discard($userId, $uploadId);
            return $this->error(
                'That file is not a video the platform can play. Use MP4 or WebM.',
                422
            );
        }

        // Replace rather than accumulate. A 50 MB file left behind is how a
        // VPS disk fills without anyone deciding to.
        if ($post->video_path && Storage::exists($post->video_path)) {
            Storage::delete($post->video_path);
        }

        $extension = $mime === 'video/webm' ? 'webm' : 'mp4';
        $finalPath = 'news/' . Str::uuid() . '.' . $extension;

        Storage::move($partPath, $finalPath);

        $post->update([
            'video_path' => $finalPath,
            'video_mime' => $mime,
            'video_size_bytes' => $meta['total_size'],
        ]);

        // The part file has become the final file, so only the metadata is
        // left to clean up. Storage::delete tolerates the missing part.
        $this->discard($userId, $uploadId);

        return response()->json([
            'success' => true,
            'message' => 'Video attached.',
            'data' => [
                'video_url' => "/news/{$post->id}/video",
                'video_size_bytes' => $post->video_size_bytes,
            ],
        ]);
    }

    /**
     * Third copy of this, now deleted. [QueueBoard] owns the ordering, and a
     * finalised upload that is still `uploaded` gets null rather than a place
     * in a line it has not joined.
     */
    private function queuePosition(AnalysisRecord $record): ?int
    {
        return app(QueueBoard::class)->positionOf($record);
    }

    private function error(string $message, int $status)
    {
        return response()->json(['success' => false, 'message' => $message], $status);
    }
}
