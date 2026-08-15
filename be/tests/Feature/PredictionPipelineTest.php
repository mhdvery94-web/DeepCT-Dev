<?php

namespace Tests\Feature;

use App\Jobs\ProcessDeepLearningImage;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;
use ZipArchive;

/**
 * Upload through to generated frames.
 *
 * The GPU worker is faked: a real call costs ~20 seconds and Kaggle quota, and
 * the thing worth testing here is our orchestration, not the model. The fake
 * reproduces the worker's actual contract, including the awkward part — a
 * handled failure comes back as JSON with **HTTP 200**.
 */
class PredictionPipelineTest extends TestCase
{
    use RefreshDatabase;

    private User $user;
    private Model $model;
    private string $token;

    protected function setUp(): void
    {
        parent::setUp();

        // Writes go to a temporary disk. RefreshDatabase rolls back the
        // database but leaves the filesystem alone, so without this every run
        // would leave real frames behind in storage/app/private/predictions.
        Storage::fake('local');

        $this->user = User::create([
            'username' => 'researcher',
            'name' => 'Researcher',
            'email' => 'researcher@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'is_active' => true,
        ]);

        $this->model = Model::create([
            'name' => 'Test Model',
            'version' => 'v1',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online',
            'is_active' => true,
            'max_concurrent_jobs' => 1,
        ]);

        $this->token = $this->tokenFor('researcher@brin.go.id', 'password123');
    }

    // ------------------------------------------------------------- fixtures

    /** A minimal but structurally valid 16-bit grayscale TIFF. */
    private function tifBytes(int $size = 4, int $phase = 0): string
    {
        $pixels = '';
        for ($y = 0; $y < $size; $y++) {
            for ($x = 0; $x < $size; $x++) {
                $pixels .= pack('v', ($x * 7 + $y * 13 + $phase * 31) % 65536);
            }
        }

        $pixelOffset = 8;
        $ifdOffset = $pixelOffset + strlen($pixels);

        $tif = 'II' . pack('v', 42) . pack('V', $ifdOffset) . $pixels;

        $ifd = pack('v', 8);
        $ifd .= pack('vvVV', 256, 3, 1, $size);
        $ifd .= pack('vvVV', 257, 3, 1, $size);
        $ifd .= pack('vvVV', 258, 3, 1, 16);
        $ifd .= pack('vvVV', 259, 3, 1, 1);
        $ifd .= pack('vvVV', 262, 3, 1, 1);
        $ifd .= pack('vvVV', 273, 4, 1, $pixelOffset);
        $ifd .= pack('vvVV', 277, 3, 1, 1);
        $ifd .= pack('vvVV', 279, 4, 1, strlen($pixels));
        $ifd .= pack('V', 0);

        return $tif . $ifd;
    }

    /**
     * @param  array<string>  $names  entry names inside the archive
     */
    private function zipFile(array $names): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'frames') . '.zip';

        $zip = new ZipArchive();
        $zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE);
        foreach (array_values($names) as $i => $name) {
            $zip->addFromString($name, $this->tifBytes(4, $i));
        }
        $zip->close();

        return new UploadedFile($path, 'frames.zip', 'application/zip', null, true);
    }

    /** The worker, answering every call with a TIFF. */
    private function fakeWorkerReturnsFrames(): void
    {
        Http::fake([
            'worker.example/*' => Http::response(
                $this->tifBytes(4, 99),
                200,
                ['Content-Type' => 'image/tiff']
            ),
        ]);
    }

    private function upload(array $names = ['frame_001.tif', 'frame_005.tif']): array
    {
        return $this->apiAs($this->token)
            ->post('/api/predictions', [
                'model_id' => $this->model->id,
                'file' => $this->zipFile($names),
            ], ['Accept' => 'application/json'])
            ->json();
    }

    // ---------------------------------------------------------------- tests

    public function test_upload_queues_a_job(): void
    {
        $this->fakeWorkerReturnsFrames();

        $response = $this->apiAs($this->token)->post('/api/predictions', [
            'model_id' => $this->model->id,
            'file' => $this->zipFile(['frame_001.tif', 'frame_005.tif']),
        ], ['Accept' => 'application/json']);

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.input_files_count', 2);

        $record = AnalysisRecord::first();
        $this->assertNotNull($record);
        $this->assertSame($this->user->id, $record->user_id);
        $this->assertNotNull($record->expires_at, 'retention window must be set');
    }

    /**
     * The whole point of the product: frames 001 and 005 leave 002, 003 and 004
     * missing, and the job must fill exactly those.
     */
    public function test_a_gap_is_filled_by_recursive_interpolation(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload(['frame_001.tif', 'frame_005.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame('completed', $record->status, $record->error_message ?? '');
        $this->assertSame(3, $record->output_files_count);
        $this->assertEqualsCanonicalizing(
            ['frame_002.tif', 'frame_003.tif', 'frame_004.tif'],
            $record->interpolated_frames
        );

        // One GPU round-trip per generated frame, no more.
        Http::assertSentCount(3);
    }

    public function test_generated_frames_keep_the_neighbours_padding(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload(['scan_0001.tif', 'scan_0005.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertEqualsCanonicalizing(
            ['scan_0002.tif', 'scan_0003.tif', 'scan_0004.tif'],
            $record->interpolated_frames
        );
    }

    public function test_the_worker_is_called_with_multipart_fields(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload();

        Http::assertSent(function ($request) {
            $names = array_column($request->data(), 'name');

            return $request->url() === 'https://worker.example/predict'
                && $request->isMultipart()
                && in_array('file_t0', $names, true)
                && in_array('file_t2', $names, true)
                && in_array('time_scalar', $names, true);
        });
    }

    /** Consecutive frames leave nothing to interpolate; fail before spending GPU time. */
    public function test_consecutive_frames_fail_without_calling_the_worker(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload(['frame_001.tif', 'frame_002.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame('failed', $record->status);
        $this->assertStringContainsString('consecutive', $record->error_message);

        Http::assertNothingSent();
    }

    /**
     * The worker reports handled failures as JSON with HTTP 200, so the status
     * code alone must not be treated as success.
     */
    public function test_a_json_error_with_http_200_is_treated_as_a_failure(): void
    {
        Http::fake([
            'worker.example/*' => Http::response(
                ['error' => 'CUDA out of memory'],
                200,
                ['Content-Type' => 'application/json']
            ),
        ]);

        $this->upload();

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame('failed', $record->status);
        $this->assertStringContainsString('CUDA out of memory', $record->error_message);
    }

    public function test_a_worker_http_error_fails_the_job(): void
    {
        Http::fake(['worker.example/*' => Http::response('gateway down', 502)]);

        $this->upload();

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame('failed', $record->status);
        $this->assertStringContainsString('502', $record->error_message);
    }

    /**
     * The concurrency counter must come back down however the job ends,
     * otherwise the model drifts towards looking permanently busy.
     */
    public function test_the_model_concurrency_counter_is_released_on_failure(): void
    {
        Http::fake(['worker.example/*' => Http::response('nope', 500)]);

        $this->upload();

        $this->assertSame(0, $this->model->fresh()->current_jobs_count);
    }

    public function test_the_model_counters_move_on_success(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload();

        $model = $this->model->fresh();
        $this->assertSame(0, $model->current_jobs_count);
        $this->assertSame(1, $model->total_predictions);
    }

    public function test_an_archive_with_one_frame_is_rejected(): void
    {
        $response = $this->apiAs($this->token)->post('/api/predictions', [
            'model_id' => $this->model->id,
            'file' => $this->zipFile(['frame_001.tif']),
        ], ['Accept' => 'application/json']);

        $response->assertStatus(422);
        $this->assertSame(0, AnalysisRecord::count());
    }

    public function test_frames_without_numbers_are_rejected(): void
    {
        $response = $this->apiAs($this->token)->post('/api/predictions', [
            'model_id' => $this->model->id,
            'file' => $this->zipFile(['start.tif', 'end.tif']),
        ], ['Accept' => 'application/json']);

        $response->assertStatus(422);
    }

    /**
     * Archives are commonly produced with a wrapping folder. Extraction
     * flattens them, because Storage::files() does not recurse and the frames
     * would otherwise be invisible to the job.
     */
    public function test_frames_nested_in_a_folder_are_still_found(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload(['sequence/frame_001.tif', 'sequence/frame_005.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame(2, $record->input_files_count);
        $this->assertSame('completed', $record->status, $record->error_message ?? '');
    }

    public function test_an_offline_model_is_refused_before_upload_work(): void
    {
        $this->model->update(['status' => 'offline']);

        $this->apiAs($this->token)->post('/api/predictions', [
            'model_id' => $this->model->id,
            'file' => $this->zipFile(['frame_001.tif', 'frame_005.tif']),
        ], ['Accept' => 'application/json'])->assertStatus(503);

        $this->assertSame(0, AnalysisRecord::count());
    }

    public function test_a_researcher_only_sees_their_own_jobs(): void
    {
        $this->fakeWorkerReturnsFrames();
        $this->upload();

        $other = User::create([
            'username' => 'other', 'name' => 'Other', 'email' => 'other@brin.go.id',
            'password' => Hash::make('password123'), 'role' => 'user', 'is_active' => true,
        ]);
        $otherToken = $this->tokenFor('other@brin.go.id', 'password123');

        $this->apiAs($otherToken)->getJson('/api/predictions')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $mine = AnalysisRecord::first();
        $this->apiAs($otherToken)->getJson("/api/predictions/{$mine->id}")
            ->assertNotFound();

        $this->assertNotNull($other);
    }

    public function test_download_is_refused_while_the_job_is_unfinished(): void
    {
        Http::fake(['worker.example/*' => Http::response('x', 500)]);
        $this->upload();

        $record = AnalysisRecord::first();
        $record->update(['status' => 'pending']);

        $this->apiAs($this->token)
            ->getJson("/api/predictions/{$record->id}/download/results")
            ->assertStatus(400);
    }

    public function test_download_of_expired_files_returns_410(): void
    {
        $this->fakeWorkerReturnsFrames();
        $this->upload();

        $record = AnalysisRecord::first();
        $record->update(['files_deleted_at' => now()]);

        $this->apiAs($this->token)
            ->getJson("/api/predictions/{$record->id}/download/results")
            ->assertStatus(410);

        $this->apiAs($this->token)
            ->getJson("/api/predictions/{$record->id}")
            ->assertOk()
            ->assertJsonPath('data.files_available', false);
    }

    public function test_deleting_a_job_removes_its_files(): void
    {
        $this->fakeWorkerReturnsFrames();
        $this->upload();

        $record = AnalysisRecord::first();
        $directory = $record->storageDirectory();

        $this->assertNotEmpty(Storage::allFiles($directory));

        $this->apiAs($this->token)
            ->deleteJson("/api/predictions/{$record->id}")
            ->assertOk();

        $this->assertEmpty(Storage::allFiles($directory));
        $this->assertSame(0, AnalysisRecord::count());
    }

    /** A crashed job must not be left sitting on `processing` forever. */
    public function test_the_failed_handler_marks_a_crashed_job(): void
    {
        $record = AnalysisRecord::create([
            'user_id' => $this->user->id,
            'job_id' => 'crash-test',
            'model_id' => $this->model->id,
            'input_folder' => 'predictions/x/input',
            'output_folder' => 'predictions/x/output',
            'status' => 'processing',
        ]);

        (new ProcessDeepLearningImage($record))->failed(new \RuntimeException('worker vanished'));

        $record->refresh();
        $this->assertSame('failed', $record->status);
        $this->assertStringContainsString('worker vanished', $record->error_message);
    }
}
