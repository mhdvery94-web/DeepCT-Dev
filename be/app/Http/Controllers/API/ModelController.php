<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Model;
use App\Models\UserActivity;
use App\Services\ModelHealthChecker;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Validator;

class ModelController extends Controller
{
    public function __construct(
        private readonly ModelHealthChecker $healthChecker,
    ) {
    }

    /**
     * Display a listing of models
     */
    public function index(Request $request)
    {
        $perPage = $request->input('per_page', 15);
        $status = $request->input('status');

        $query = Model::query();

        // Filter by status
        if ($status) {
            $query->where('status', $status);
        }

        $models = $query->orderBy('created_at', 'desc')->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $models->items(),
            'pagination' => [
                'total' => $models->total(),
                'per_page' => $models->perPage(),
                'current_page' => $models->currentPage(),
                'last_page' => $models->lastPage(),
                'from' => $models->firstItem(),
                'to' => $models->lastItem(),
            ],
        ]);
    }

    /**
     * Store a newly created model
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'version' => 'required|string|max:50',
            // 'inference' answers POST /predict, 'trainer' answers POST /train.
            // One registry: registering a trainer is the same act, with the
            // same on/off switch and the same health check behind it.
            'kind' => 'nullable|in:inference,trainer',
            'endpoint_url' => 'required|url|max:500',
            'description' => 'nullable|string',
            'file_path' => 'nullable|string|max:255',
            // Sent to the worker as `Authorization: Bearer`. Write-only: it
            // goes in here and is never returned by any endpoint.
            'auth_token' => 'nullable|string|max:500',
            'verify_tls' => 'nullable|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $model = Model::create([
            'name' => $request->name,
            'version' => $request->version,
            'kind' => $request->input('kind', 'inference'),
            'endpoint_url' => $request->endpoint_url,
            'auth_token' => $request->input('auth_token') ?: null,
            // Defaults false to match every worker registered before this
            // existed; the admin form offers it checked when creating, so a
            // new endpoint gets the secure answer without an old one changing
            // behaviour underneath it.
            'verify_tls' => $request->boolean('verify_tls'),
            'description' => $request->description,
            // Models are deployed remotely (Kaggle/Colab) and reached via
            // endpoint_url, so there is no local weights file to reference.
            'file_path' => $request->input('file_path'),
            'is_active' => true,
            'status' => 'offline',
            'current_jobs_count' => 0,
            'total_predictions' => 0,
            'deployed_at' => now(),
        ]);

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'model_id' => $model->id,
            'activity_type' => 'create_model',
            'description' => "Menambahkan model baru: {$model->name} {$model->version}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'model_id' => $model->id,
                'endpoint_url' => $model->endpoint_url,
            ],
        ]);

        // Auto health check
        $this->performHealthCheck($model);

        return response()->json([
            'success' => true,
            'message' => 'Model berhasil ditambahkan',
            'data' => $model->fresh(),
        ], 201);
    }

    /**
     * Display the specified model
     */
    public function show($id)
    {
        $model = Model::findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $model,
        ]);
    }

    /**
     * Update the specified model
     */
    public function update(Request $request, $id)
    {
        $model = Model::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:255',
            'version' => 'sometimes|required|string|max:50',
            'endpoint_url' => 'sometimes|required|url|max:500',
            'description' => 'nullable|string',
            // Omitted leaves the stored secret alone; an empty string clears
            // it. Those are different intentions and a form that cannot tell
            // them apart would wipe the credential every time somebody fixed
            // a typo in the description.
            'auth_token' => 'sometimes|nullable|string|max:500',
            'verify_tls' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $oldData = $model->only(['name', 'version', 'endpoint_url']);
        $model->update($request->only(['name', 'version', 'endpoint_url', 'description']));

        // Handled apart from the mass update so "not sent" and "sent empty"
        // stay distinguishable. `only()` would collapse both to absent.
        if ($request->has('auth_token')) {
            $model->update(['auth_token' => $request->input('auth_token') ?: null]);
        }

        if ($request->has('verify_tls')) {
            $model->update(['verify_tls' => $request->boolean('verify_tls')]);
        }

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'model_id' => $model->id,
            'activity_type' => 'update_model',
            'description' => "Mengupdate model: {$model->name}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'model_id' => $model->id,
                'old_data' => $oldData,
                'new_data' => $model->only(['name', 'version', 'endpoint_url']),
            ],
        ]);

        // If endpoint changed, check health
        if ($request->has('endpoint_url') && $oldData['endpoint_url'] !== $model->endpoint_url) {
            $this->performHealthCheck($model);
        }

        return response()->json([
            'success' => true,
            'message' => 'Model berhasil diupdate',
            'data' => $model->fresh(),
        ]);
    }

    /**
     * Remove the specified model
     */
    public function destroy(Request $request, $id)
    {
        $model = Model::findOrFail($id);

        // Check if model has active jobs
        if ($model->current_jobs_count > 0) {
            return response()->json([
                'success' => false,
                'message' => 'Tidak dapat menghapus model yang sedang memproses job',
            ], 403);
        }

        $modelName = $model->name;
        $model->delete();

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'activity_type' => 'delete_model',
            'description' => "Menghapus model: {$modelName}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'deleted_model_id' => $id,
                'model_name' => $modelName,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Model berhasil dihapus',
        ]);
    }

    /**
     * Toggle model active status
     */
    public function toggleStatus(Request $request, $id)
    {
        $model = Model::findOrFail($id);

        // Check if has active jobs
        if ($model->is_active && $model->current_jobs_count > 0) {
            return response()->json([
                'success' => false,
                'message' => 'Tidak dapat menonaktifkan model yang sedang memproses job',
            ], 403);
        }

        $model->is_active = !$model->is_active;
        $model->save();

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'model_id' => $model->id,
            'activity_type' => 'toggle_model_status',
            'description' => "Mengubah status model {$model->name} menjadi " . ($model->is_active ? 'aktif' : 'nonaktif'),
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'model_id' => $model->id,
                'new_status' => $model->is_active,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Status model berhasil diupdate',
            'data' => [
                'id' => $model->id,
                'is_active' => $model->is_active,
            ],
        ]);
    }

    /**
     * Check model health (manual)
     */
    public function healthCheck(Request $request, $id)
    {
        $model = Model::findOrFail($id);

        $result = $this->performHealthCheck($model);

        // Log activity
        UserActivity::create([
            'user_id' => auth()->id(),
            'model_id' => $model->id,
            'activity_type' => 'health_check',
            'description' => "Melakukan health check pada model: {$model->name}",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => [
                'model_id' => $model->id,
                'status' => $result['status'],
                'response_time_ms' => $result['response_time_ms'] ?? null,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Health check selesai',
            'data' => [
                'model_id' => $model->id,
                'status' => $result['status'],
                'response_time_ms' => $result['response_time_ms'] ?? null,
                'checked_at' => $model->fresh()->last_health_check,
                'error' => $result['error'] ?? null,
            ],
        ]);
    }

    /**
     * Test prediction with sample data
     */
    public function testPrediction(Request $request, $id)
    {
        $model = Model::findOrFail($id);

        if (!$model->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Model tidak aktif',
            ], 403);
        }

        if ($model->status !== 'online') {
            return response()->json([
                'success' => false,
                'message' => "Model sedang {$model->status}, tidak dapat melakukan test prediksi",
            ], 503);
        }

        try {
            $startTime = microtime(true);

            // The worker exposes `POST /predict` as multipart/form-data with
            // two 16-bit TIFF frames plus the interpolation position. Sending
            // JSON here returns 422, so we upload two small generated frames.
            $sampleTif = $this->makeSampleTif();

            $response = app(WorkerRequest::class)
                ->for($model, 120)
                ->attach('file_t0', $sampleTif, 'test_t0.tif', ['Content-Type' => 'image/tiff'])
                ->attach('file_t2', $sampleTif, 'test_t2.tif', ['Content-Type' => 'image/tiff'])
                ->post($model->endpoint_url, [
                    'time_scalar' => '0.5',
                ]);

            $responseTime = round((microtime(true) - $startTime) * 1000, 2);

            if ($response->failed()) {
                throw new \Exception(
                    'Worker returned HTTP ' . $response->status() . ': ' . $this->summarise($response->body())
                );
            }

            // A successful run streams back a TIFF; a handled failure returns
            // JSON shaped as {"error": "..."} with HTTP 200.
            $contentType = strtolower((string) $response->header('Content-Type'));
            $isImage = str_contains($contentType, 'image/');

            if (! $isImage) {
                $payload = $response->json();

                if (is_array($payload) && isset($payload['error'])) {
                    throw new \Exception('Worker error: ' . $payload['error']);
                }

                throw new \Exception(
                    'Unexpected response type "' . $contentType . '": ' . $this->summarise($response->body())
                );
            }

            $bytes = strlen($response->body());

            // Log activity
            UserActivity::create([
                'user_id' => auth()->id(),
                'model_id' => $model->id,
                'activity_type' => 'test_prediction',
                'description' => "Melakukan test prediksi pada model: {$model->name}",
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'metadata' => [
                    'model_id' => $model->id,
                    'response_time_ms' => $responseTime,
                    'result_bytes' => $bytes,
                    'success' => true,
                ],
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Test prediksi berhasil',
                'data' => [
                    'response_time_ms' => $responseTime,
                    'model_response' => [
                        'content_type' => $contentType,
                        'result_bytes' => $bytes,
                    ],
                ],
            ]);

        } catch (\Exception $e) {
            // Log activity
            UserActivity::create([
                'user_id' => auth()->id(),
                'model_id' => $model->id,
                'activity_type' => 'test_prediction',
                'description' => "Test prediksi gagal pada model: {$model->name}",
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'metadata' => [
                    'model_id' => $model->id,
                    'success' => false,
                    'error' => $e->getMessage(),
                ],
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Test prediksi gagal',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Perform health check on a model.
     *
     * Delegates to {@see ModelHealthChecker} so the scheduled command and this
     * controller cannot drift apart.
     *
     * @internal
     */
    private function performHealthCheck(Model $model)
    {
        return $this->healthChecker->check($model);
    }

    /**
     * Build a minimal uncompressed 16-bit grayscale TIFF in memory.
     *
     * The worker resizes whatever it receives to 1024x1024, so a tiny frame is
     * enough to exercise the full request path without shipping a fixture file.
     *
     * @internal
     */
    private function makeSampleTif(int $size = 8): string
    {
        $pixels = '';
        for ($y = 0; $y < $size; $y++) {
            for ($x = 0; $x < $size; $x++) {
                // Simple gradient so the frame is not uniformly black.
                $pixels .= pack('v', (int) (($x + $y) / (2 * max($size - 1, 1)) * 65535));
            }
        }

        $entryCount = 8;
        $headerSize = 8;
        $pixelOffset = $headerSize;
        $ifdOffset = $pixelOffset + strlen($pixels);

        // Little-endian TIFF header pointing at the IFD placed after the data.
        $tif = "II" . pack('v', 42) . pack('V', $ifdOffset);
        $tif .= $pixels;

        // Each IFD entry: tag, type (3=SHORT, 4=LONG), count, value.
        $ifd = pack('v', $entryCount);
        $ifd .= pack('vvVV', 256, 3, 1, $size);         // ImageWidth
        $ifd .= pack('vvVV', 257, 3, 1, $size);         // ImageLength
        $ifd .= pack('vvVV', 258, 3, 1, 16);            // BitsPerSample
        $ifd .= pack('vvVV', 259, 3, 1, 1);             // Compression = none
        $ifd .= pack('vvVV', 262, 3, 1, 1);             // BlackIsZero
        $ifd .= pack('vvVV', 273, 4, 1, $pixelOffset);  // StripOffsets
        $ifd .= pack('vvVV', 277, 3, 1, 1);             // SamplesPerPixel
        $ifd .= pack('vvVV', 279, 4, 1, strlen($pixels)); // StripByteCounts
        $ifd .= pack('V', 0);                           // No further IFD

        return $tif . $ifd;
    }

    /** Trim a worker response body for safe inclusion in an error message. */
    private function summarise(string $body): string
    {
        $body = trim(preg_replace('/\s+/', ' ', $body) ?? '');

        return strlen($body) > 200 ? substr($body, 0, 200) . '...' : $body;
    }
}
