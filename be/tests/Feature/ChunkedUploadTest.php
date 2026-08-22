<?php

namespace Tests\Feature;

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
 * The resumable upload flow.
 *
 * The guard rails matter more than the happy path here: a chunk accepted at
 * the wrong offset would assemble a corrupt archive that only fails much later,
 * during extraction, with a message pointing nowhere useful.
 */
class ChunkedUploadTest extends TestCase
{
    use RefreshDatabase;

    private User $user;
    private Model $model;
    private string $token;
    private string $archive;

    protected function setUp(): void
    {
        parent::setUp();

        // Writes go to a temporary disk. RefreshDatabase rolls back the
        // database but leaves the filesystem alone, so without this every run
        // would leave real frames behind in storage/app/private/predictions.
        Storage::fake('local');

        $this->user = User::create([
            'name' => 'Researcher',
            'email' => 'researcher@brin.go.id', 'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);

        $this->model = Model::create([
            'name' => 'Test Model', 'version' => 'v1',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online', 'is_active' => true, 'max_concurrent_jobs' => 1,
        ]);

        $this->token = $this->tokenFor('researcher@brin.go.id', 'password123');
        $this->archive = $this->buildArchive();

        Http::fake([
            'worker.example/*' => Http::response(
                $this->tifBytes(4, 9), 200, ['Content-Type' => 'image/tiff']
            ),
        ]);
    }

    private function tifBytes(int $size = 4, int $phase = 0): string
    {
        $pixels = '';
        for ($y = 0; $y < $size; $y++) {
            for ($x = 0; $x < $size; $x++) {
                $pixels .= pack('v', ($x * 7 + $y * 13 + $phase * 31) % 65536);
            }
        }
        $off = 8;
        $tif = 'II' . pack('v', 42) . pack('V', $off + strlen($pixels)) . $pixels;
        $ifd = pack('v', 8)
            . pack('vvVV', 256, 3, 1, $size) . pack('vvVV', 257, 3, 1, $size)
            . pack('vvVV', 258, 3, 1, 16) . pack('vvVV', 259, 3, 1, 1)
            . pack('vvVV', 262, 3, 1, 1) . pack('vvVV', 273, 4, 1, $off)
            . pack('vvVV', 277, 3, 1, 1) . pack('vvVV', 279, 4, 1, strlen($pixels))
            . pack('V', 0);

        return $tif . $ifd;
    }

    private function buildArchive(): string
    {
        $path = tempnam(sys_get_temp_dir(), 'chunk') . '.zip';
        $zip = new ZipArchive();
        $zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE);
        $zip->addFromString('frame_001.tif', $this->tifBytes(4, 0));
        $zip->addFromString('frame_005.tif', $this->tifBytes(4, 3));
        $zip->close();

        return file_get_contents($path);
    }

    /** Open a session and return its id. */
    private function start(?int $totalSize = null): string
    {
        return $this->apiAs($this->token)->postJson('/api/predictions/uploads', [
            'model_id' => $this->model->id,
            'total_size' => $totalSize ?? strlen($this->archive),
            'filename' => 'frames.zip',
        ])->assertCreated()->json('data.upload_id');
    }

    private function sendChunk(string $uploadId, int $offset, string $body)
    {
        return $this->apiAs($this->token)->post(
            "/api/predictions/uploads/{$uploadId}",
            [
                '_method' => 'PATCH',
                'offset' => $offset,
                'chunk' => UploadedFile::fake()->createWithContent('chunk', $body),
            ],
            ['Accept' => 'application/json']
        );
    }

    // ---------------------------------------------------------------- tests

    public function test_the_advertised_chunk_size_fits_php_upload_limits(): void
    {
        $chunkSize = $this->apiAs($this->token)->postJson('/api/predictions/uploads', [
            'model_id' => $this->model->id,
            'total_size' => 1024,
        ])->assertCreated()->json('data.chunk_size');

        $toBytes = function (string $key): ?int {
            $raw = trim((string) ini_get($key));
            if ($raw === '' || $raw === '-1') return null;
            $v = (int) $raw;
            return match (strtolower(substr($raw, -1))) {
                'g' => $v * 1073741824, 'm' => $v * 1048576, 'k' => $v * 1024, default => $v,
            };
        };

        $limits = array_filter([$toBytes('upload_max_filesize'), $toBytes('post_max_size')]);

        if ($limits !== []) {
            $this->assertLessThan(
                min($limits),
                $chunkSize,
                'a chunk PHP would reject is worse than no chunking at all'
            );
        }

        $this->assertGreaterThan(0, $chunkSize);
    }

    public function test_a_complete_chunked_upload_queues_a_job(): void
    {
        $uploadId = $this->start();

        $chunkSize = 100;
        for ($offset = 0; $offset < strlen($this->archive); $offset += $chunkSize) {
            $slice = substr($this->archive, $offset, $chunkSize);
            $this->sendChunk($uploadId, $offset, $slice)->assertOk();
        }

        $this->apiAs($this->token)
            ->postJson("/api/predictions/uploads/{$uploadId}/finalize")
            ->assertCreated()
            ->assertJsonPath('data.input_files_count', 2);

        $record = AnalysisRecord::first()->fresh();
        $this->assertSame('completed', $record->status, $record->error_message ?? '');
        $this->assertSame(3, $record->output_files_count);
        $this->assertSame('frames.zip', $record->file_name);
    }

    public function test_the_status_endpoint_reports_progress_for_resuming(): void
    {
        $uploadId = $this->start();
        $this->sendChunk($uploadId, 0, substr($this->archive, 0, 50))->assertOk();

        $this->apiAs($this->token)
            ->getJson("/api/predictions/uploads/{$uploadId}")
            ->assertOk()
            ->assertJsonPath('data.received', 50)
            ->assertJsonPath('data.complete', false);
    }

    public function test_an_out_of_order_chunk_is_refused(): void
    {
        $uploadId = $this->start();
        $this->sendChunk($uploadId, 0, substr($this->archive, 0, 50))->assertOk();

        $this->sendChunk($uploadId, 500, 'skipped ahead')
            ->assertStatus(409)
            ->assertJsonPath('success', false);

        $this->apiAs($this->token)
            ->getJson("/api/predictions/uploads/{$uploadId}")
            ->assertJsonPath('data.received', 50);
    }

    /** A client retrying after a dropped response must not double-write. */
    public function test_resending_a_chunk_is_idempotent(): void
    {
        $uploadId = $this->start();
        $slice = substr($this->archive, 0, 50);

        $this->sendChunk($uploadId, 0, $slice)->assertOk();
        $this->sendChunk($uploadId, 0, $slice)->assertOk();

        $this->apiAs($this->token)
            ->getJson("/api/predictions/uploads/{$uploadId}")
            ->assertJsonPath('data.received', 50);
    }

    public function test_finalizing_an_incomplete_upload_is_refused(): void
    {
        $uploadId = $this->start();
        $this->sendChunk($uploadId, 0, substr($this->archive, 0, 50))->assertOk();

        $this->apiAs($this->token)
            ->postJson("/api/predictions/uploads/{$uploadId}/finalize")
            ->assertStatus(409);

        $this->assertSame(0, AnalysisRecord::count());
    }

    public function test_a_chunk_beyond_the_declared_size_is_refused(): void
    {
        $uploadId = $this->start(50);

        $this->sendChunk($uploadId, 0, str_repeat('x', 200))
            ->assertStatus(422);
    }

    /**
     * Ownership is enforced by the storage path, so another account's session
     * id does not resolve at all.
     */
    public function test_another_account_cannot_touch_the_session(): void
    {
        $uploadId = $this->start();

        User::create([
            'name' => 'Other', 'email' => 'other@brin.go.id',
            'password' => Hash::make('password123'), 'role' => 'user', 'is_active' => true,
        ]);
        $otherToken = $this->tokenFor('other@brin.go.id', 'password123');

        $this->apiAs($otherToken)
            ->getJson("/api/predictions/uploads/{$uploadId}")
            ->assertNotFound();

        $this->apiAs($otherToken)
            ->postJson("/api/predictions/uploads/{$uploadId}/finalize")
            ->assertNotFound();

        $this->apiAs($otherToken)
            ->deleteJson("/api/predictions/uploads/{$uploadId}")
            ->assertNotFound();
    }

    public function test_aborting_removes_the_partial_file(): void
    {
        $uploadId = $this->start();
        $this->sendChunk($uploadId, 0, substr($this->archive, 0, 50))->assertOk();

        $this->assertNotEmpty(Storage::allFiles("temp/uploads/{$this->user->id}"));

        $this->apiAs($this->token)
            ->deleteJson("/api/predictions/uploads/{$uploadId}")
            ->assertOk();

        $this->assertEmpty(Storage::allFiles("temp/uploads/{$this->user->id}"));
    }

    public function test_finalizing_cleans_up_the_session_files(): void
    {
        $uploadId = $this->start();

        $chunkSize = 100;
        for ($offset = 0; $offset < strlen($this->archive); $offset += $chunkSize) {
            $this->sendChunk($uploadId, $offset, substr($this->archive, $offset, $chunkSize));
        }

        $this->apiAs($this->token)
            ->postJson("/api/predictions/uploads/{$uploadId}/finalize")
            ->assertCreated();

        $this->assertEmpty(
            Storage::allFiles("temp/uploads/{$this->user->id}"),
            'the assembled archive is not needed once the job is queued'
        );
    }

    public function test_opening_a_session_against_an_offline_model_is_refused(): void
    {
        $this->model->update(['status' => 'offline']);

        $this->apiAs($this->token)->postJson('/api/predictions/uploads', [
            'model_id' => $this->model->id,
            'total_size' => 1024,
        ])->assertStatus(503);
    }

    /**
     * `purpose` is optional, and saying `prediction` out loud must mean the
     * same thing as leaving it out.
     *
     * It did not. The rule was `required_without:purpose`, which asks whether
     * the *field* is present rather than what it says, so naming the default
     * switched `model_id` off — and the controller then read a key that
     * validation had just agreed did not have to be there. The caller got a
     * 500 with a stack trace where a 422 naming the missing field belonged.
     */
    public function test_naming_the_default_purpose_still_requires_a_model(): void
    {
        $this->apiAs($this->token)->postJson('/api/predictions/uploads', [
            'purpose' => 'prediction',
            'total_size' => 1024,
        ])->assertStatus(422)->assertJsonValidationErrors('model_id');
    }

    /** The same request, with the field left out, has always been a 422. */
    public function test_omitting_the_purpose_still_requires_a_model(): void
    {
        $this->apiAs($this->token)->postJson('/api/predictions/uploads', [
            'total_size' => 1024,
        ])->assertStatus(422)->assertJsonValidationErrors('model_id');
    }

    /** And a training session is the one case that needs no model at all. */
    public function test_a_training_session_needs_no_model(): void
    {
        $this->apiAs($this->token)->postJson('/api/predictions/uploads', [
            'purpose' => 'training',
            'name' => 'Balanced t sweep',
            'total_epochs' => 5,
            'total_size' => 1024,
        ])->assertStatus(201);
    }
}
