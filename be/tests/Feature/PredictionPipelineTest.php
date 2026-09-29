<?php

namespace Tests\Feature;

use App\Jobs\CaptureResultEvidence;
use App\Jobs\ProcessDeepLearningImage;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use App\Services\ResultEvidence;
use App\Services\ResultManifest;
use App\Services\StorageGuard;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
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

    /**
     * Upload and start, which used to be one request and is now two.
     *
     * The split exists so a researcher can look at the frames before spending
     * a GPU slot on them. Every test below is about what happens once the run
     * is going, so the helper does both halves — the queue is `sync` here, so
     * starting runs the job inline exactly as dispatching used to.
     */
    private function upload(array $names = ['frame_001.tif', 'frame_005.tif']): array
    {
        $body = $this->apiAs($this->token)
            ->post('/api/predictions', [
                'model_id' => $this->model->id,
                'file' => $this->zipFile($names),
            ], ['Accept' => 'application/json'])
            ->json();

        $id = $body['data']['id'] ?? null;

        if ($id !== null) {
            $this->apiAs($this->token)->postJson("/api/predictions/{$id}/start");
        }

        return $body;
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

    public function test_foldered_frames_with_the_same_basename_are_rejected(): void
    {
        $this->apiAs($this->token)->post('/api/predictions', [
            'model_id' => $this->model->id,
            'file' => $this->zipFile([
                'first/frame_001.tif',
                'second/frame_001.tif',
                'frame_005.tif',
            ]),
        ], ['Accept' => 'application/json'])
            ->assertStatus(422);

        $this->assertSame(0, AnalysisRecord::count());
    }

    public function test_expanded_zip_size_is_checked_before_extraction(): void
    {
        $guard = new class extends StorageGuard {
            public array $checked = [];

            public function refusalFor(int $uploadBytes): ?string
            {
                $this->checked[] = $uploadBytes;

                return $uploadBytes > 10000 ? 'Not enough space for expanded frames.' : null;
            }
        };
        $this->app->instance(StorageGuard::class, $guard);

        $path = tempnam(sys_get_temp_dir(), 'expanded') . '.zip';
        $zip = new ZipArchive();
        $zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE);
        $zip->addFromString('frame_001.tif', str_repeat('a', 20000));
        $zip->addFromString('frame_005.tif', str_repeat('b', 20000));
        $zip->close();

        $this->apiAs($this->token)->post('/api/predictions', [
            'model_id' => $this->model->id,
            'file' => new UploadedFile($path, 'frames.zip', 'application/zip', null, true),
        ], ['Accept' => 'application/json'])
            ->assertStatus(507);

        $this->assertCount(2, $guard->checked);
        $this->assertGreaterThan(10000, $guard->checked[1]);
        $this->assertSame([], Storage::allFiles('predictions'));
        $this->assertSame(0, AnalysisRecord::count());
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

    /**
     * Not every generated frame is equally trustworthy, and this is the record
     * that says so.
     *
     * Between 001 and 005 the midpoint 003 is drawn first, from two frames that
     * came off the scanner. Only then are 002 and 004 drawn — and each of those
     * has 003 as one of its boundaries, so the model is being fed its own
     * output. A folder of five TIFFs cannot tell anyone that; this can.
     */
    public function test_provenance_records_the_parents_and_generation_of_each_frame(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload(['frame_001.tif', 'frame_005.tif']);

        $record = AnalysisRecord::first()->fresh();
        $byIndex = collect($record->frame_provenance)->keyBy('index');

        $this->assertCount(3, $record->frame_provenance);

        // Drawn between two scanned frames.
        $this->assertSame([1, 5], $byIndex[3]['from']);
        $this->assertSame(1, $byIndex[3]['generation']);
        $this->assertSame(0, $byIndex[3]['synthetic_parents']);

        // Drawn against 003, which the model had just invented.
        $this->assertSame([1, 3], $byIndex[2]['from']);
        $this->assertSame(2, $byIndex[2]['generation']);
        $this->assertSame(1, $byIndex[2]['synthetic_parents']);

        $this->assertSame([3, 5], $byIndex[4]['from']);
        $this->assertSame(2, $byIndex[4]['generation']);
        $this->assertSame(1, $byIndex[4]['synthetic_parents']);

        // The filename is carried too, so the record joins to the archive
        // without anyone having to reconstruct the padding rules.
        $this->assertSame('frame_003.tif', $byIndex[3]['frame']);
    }

    /** A one-frame gap needs no recursion, and nothing should claim otherwise. */
    public function test_a_single_missing_frame_is_first_generation(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload(['frame_001.tif', 'frame_003.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertCount(1, $record->frame_provenance);
        $this->assertSame(1, $record->frame_provenance[0]['generation']);
        $this->assertSame(0, $record->frame_provenance[0]['synthetic_parents']);
    }

    /**
     * The only ground truth this platform can have.
     *
     * Frames 001, 002 and 003 are three in a row, so 002 can be held out,
     * drawn again from 001 and 003, and measured against the frame that was
     * really there. The worker is faked and returns a fixed pattern, so the
     * numbers here are arbitrary — what is being tested is that a measurement
     * is taken at all, and against the right frame.
     */
    public function test_a_consecutive_triplet_is_measured_against_itself(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload(['frame_001.tif', 'frame_002.tif', 'frame_003.tif', 'frame_007.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame('completed', $record->status, $record->error_message ?? '');
        $this->assertIsArray($record->validation);
        $this->assertArrayNotHasKey('error', $record->validation);

        $this->assertSame('frame_002.tif', $record->validation['held_out_frame']);
        $this->assertSame(2, $record->validation['index']);
        $this->assertSame([1, 3], $record->validation['from']);

        // Real numbers, in raw 16-bit counts, plus the range they sit in.
        // Numeric rather than float: a whole number survives the JSON column
        // as an int, and 0 is a perfectly good MAE.
        $this->assertIsNumeric($record->validation['mae']);
        $this->assertGreaterThanOrEqual(0, $record->validation['mae']);
        $this->assertArrayHasKey('psnr', $record->validation);
        $this->assertArrayHasKey('reference_max', $record->validation);
        $this->assertSame(16, $record->validation['pixels']);
    }

    /**
     * The case the first real archive brought, and the one the original rule
     * got wrong.
     *
     * Frames 51, 53, 55 … every other one, which is what an upload to this
     * platform actually looks like: a researcher uploads frames *with gaps*.
     * There is no consecutive triplet anywhere in it — and yet 53 is the exact
     * midpoint of 51 and 55, and can be held out and checked immediately.
     */
    public function test_evenly_spaced_frames_are_measured(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload([
            'HONDA_0051.tif', 'HONDA_0053.tif', 'HONDA_0055.tif', 'HONDA_0057.tif',
        ]);

        $record = AnalysisRecord::first()->fresh();

        $this->assertIsArray(
            $record->validation,
            'an archive of alternate frames offers plenty to hold out'
        );
        $this->assertArrayNotHasKey('error', $record->validation);

        // The tightest span, not the widest: 51-55 is two interpolations
        // apart, which is the problem the model is actually given. 51-59 would
        // measure it on something harder.
        $this->assertSame([51, 55], $record->validation['from']);
        $this->assertSame(53, $record->validation['index']);
    }

    /** An upload with no midpoint among its frames has nothing to hold out. */
    public function test_an_archive_without_a_midpoint_is_not_measured(): void
    {
        $this->fakeWorkerReturnsFrames();

        // 1, 3 and 7. The spans are 2, 4 and 6; their midpoints are 2, 4 and 5,
        // and not one of those was uploaded. This is a real archive from a real
        // run, and it genuinely offers nothing.
        $this->upload(['frame_001.tif', 'frame_003.tif', 'frame_007.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame('completed', $record->status, $record->error_message ?? '');
        $this->assertNull(
            $record->validation,
            'nothing to hold out is an ordinary case, not a failure'
        );
    }

    public function test_an_odd_span_is_never_chosen(): void
    {
        // Frames 1, 4 and 6: spans of 3, 2 and 5. Only 4-6 is even, and its
        // midpoint 5 was not uploaded. An odd span has no midpoint at all, and
        // asking the model for one would compare against the wrong frame.
        $this->fakeWorkerReturnsFrames();

        $this->upload(['frame_001.tif', 'frame_004.tif', 'frame_006.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame('completed', $record->status, $record->error_message ?? '');
        $this->assertNull($record->validation);
    }

    /**
     * The measurement is worth having, but never at the price of the frames
     * the researcher actually asked for.
     */
    public function test_a_failed_measurement_does_not_fail_the_job(): void
    {
        // Three good frames for the results, then a worker that has stopped
        // answering by the time the hold-out call goes out.
        Http::fakeSequence()
            ->push($this->tifBytes(4, 99), 200, ['Content-Type' => 'image/tiff'])
            ->push($this->tifBytes(4, 98), 200, ['Content-Type' => 'image/tiff'])
            ->push($this->tifBytes(4, 97), 200, ['Content-Type' => 'image/tiff'])
            ->push('{"error":"out of memory"}', 200, ['Content-Type' => 'application/json']);

        $this->upload(['frame_001.tif', 'frame_002.tif', 'frame_003.tif', 'frame_007.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame('completed', $record->status, $record->error_message ?? '');
        $this->assertArrayHasKey('error', $record->validation);
    }

    /**
     * The manifest that travels inside the archive.
     *
     * Built from the record and the two file lists rather than exercised
     * through the download endpoint: that route streams a temporary file and
     * deletes it as it goes, so a test reading it back is testing Symfony's
     * file handling rather than what the manifest says.
     */
    public function test_the_manifest_tells_scanned_frames_from_generated_ones(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload(['frame_001.tif', 'frame_005.tif']);
        $record = AnalysisRecord::first()->fresh();

        $csv = app(ResultManifest::class)->csv(
            $record,
            Storage::files($record->input_folder),
            Storage::files($record->output_folder)
        );

        $this->assertStringContainsString(
            'frame,origin,interpolated_from,generation,synthetic_parents',
            $csv
        );

        // A scanned frame carries no parents, because it has none.
        $this->assertStringContainsString('frame_001.tif,scanned,,,', $csv);

        // The midpoint: drawn between the two scanned frames, generation 1.
        $this->assertStringContainsString('frame_003.tif,generated,1+5,1,0', $csv);

        // And one drawn against that midpoint, which the model had invented.
        $this->assertStringContainsString('frame_002.tif,generated,1+3,2,1', $csv);
    }

    /**
     * Two models on the same frames, which is what makes the registry an
     * instrument rather than plumbing.
     */
    public function test_a_rerun_copies_the_frames_and_links_back(): void
    {
        $this->fakeWorkerReturnsFrames();

        $body = $this->upload(['frame_001.tif', 'frame_005.tif']);
        $original = AnalysisRecord::first()->fresh();

        $other = Model::create([
            'name' => 'Second opinion',
            'version' => '2.0',
            'endpoint_url' => 'https://worker.example/predict',
            'is_active' => true,
        ]);

        $response = $this->apiAs($this->token)
            ->postJson("/api/predictions/{$body['data']['id']}/rerun", [
                'model_id' => $other->id,
            ]);

        $response->assertCreated()->assertJsonPath('data.rerun_of_id', $original->id);

        $rerun = AnalysisRecord::where('id', '!=', $original->id)->firstOrFail();

        $this->assertSame($other->id, $rerun->model_id);
        $this->assertSame($original->id, $rerun->rerun_of_id);

        // Copied, not shared. Deleting either job must not strip the other of
        // the frames it was measured on.
        $this->assertNotSame($original->input_folder, $rerun->input_folder);
        $this->assertCount(2, Storage::files($rerun->input_folder));
        $this->assertCount(2, Storage::files($original->input_folder));
    }

    public function test_the_detail_endpoint_lists_every_run_on_the_same_frames(): void
    {
        $this->fakeWorkerReturnsFrames();

        $body = $this->upload(['frame_001.tif', 'frame_005.tif']);
        $id = $body['data']['id'];

        $other = Model::create([
            'name' => 'Second opinion',
            'version' => '2.0',
            'endpoint_url' => 'https://worker.example/predict',
            'is_active' => true,
        ]);

        $this->apiAs($this->token)
            ->postJson("/api/predictions/{$id}/rerun", ['model_id' => $other->id]);

        $this->apiAs($this->token)
            ->getJson("/api/predictions/{$id}")
            ->assertOk()
            ->assertJsonCount(2, 'data.comparison')
            ->assertJsonPath('data.comparison.0.is_current', true)
            ->assertJsonPath('data.comparison.1.model', 'Second opinion');
    }

    /** A single run is not a comparison, and must not be dressed up as one. */
    public function test_a_lone_run_reports_no_comparison(): void
    {
        $this->fakeWorkerReturnsFrames();

        $body = $this->upload(['frame_001.tif', 'frame_005.tif']);

        $this->apiAs($this->token)
            ->getJson("/api/predictions/{$body['data']['id']}")
            ->assertOk()
            ->assertJsonCount(0, 'data.comparison');
    }

    public function test_a_rerun_of_expired_frames_is_refused(): void
    {
        $this->fakeWorkerReturnsFrames();

        $body = $this->upload(['frame_001.tif', 'frame_005.tif']);
        $record = AnalysisRecord::first();
        $record->update(['files_deleted_at' => now()]);

        $this->apiAs($this->token)
            ->postJson("/api/predictions/{$body['data']['id']}/rerun", [
                'model_id' => $this->model->id,
            ])
            ->assertStatus(410);
    }

    /**
     * Rendering the thumbnails is CPU-bound pure PHP — half a second a frame
     * here, several times that on a Raspberry Pi. It has no business holding
     * the GPU queue open after the work the researcher asked for is finished.
     */
    public function test_the_thumbnails_are_queued_rather_than_rendered_inline(): void
    {
        // Only this one. A blanket `Queue::fake()` would intercept the
        // interpolation job as well, and a job that never runs cannot dispatch
        // anything for the assertion to find.
        Queue::fake([CaptureResultEvidence::class]);
        $this->fakeWorkerReturnsFrames();

        $this->upload(['frame_001.tif', 'frame_005.tif']);

        Queue::assertPushed(CaptureResultEvidence::class);

        // And nothing was rendered inline while the queue held the job.
        $record = AnalysisRecord::first()->fresh();
        $this->assertSame('completed', $record->status, $record->error_message ?? '');
        $this->assertEmpty(app(ResultEvidence::class)->listFor($record));
    }

    /**
     * The whole reason the thumbnails exist: they have to still be there when
     * the frames are not.
     */
    public function test_kept_thumbnails_survive_the_retention_sweep(): void
    {
        $this->fakeWorkerReturnsFrames();

        $body = $this->upload(['frame_001.tif', 'frame_005.tif']);
        $id = $body['data']['id'];

        $record = AnalysisRecord::first()->fresh();
        $kept = app(ResultEvidence::class)->listFor($record);

        $this->assertNotEmpty($kept, 'a completed run must leave something behind');

        // Expire it and run the sweep that deletes the real frames.
        $record->update(['expires_at' => now()->subHour()]);
        $this->artisan('predictions:cleanup')->assertExitCode(0);

        $record->refresh();
        $this->assertNotNull($record->files_deleted_at, 'the frames should be gone');
        $this->assertEmpty(Storage::files($record->output_folder));

        // And the evidence is still there.
        $this->assertSame($kept, app(ResultEvidence::class)->listFor($record));

        $this->apiAs($this->token)
            ->get("/api/predictions/{$id}/evidence/{$kept[0]}")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png');
    }

    public function test_deleting_a_job_takes_its_thumbnails_too(): void
    {
        // Surviving expiry is not the same as surviving deletion. Someone who
        // deletes a job expects it gone.
        $this->fakeWorkerReturnsFrames();

        $body = $this->upload(['frame_001.tif', 'frame_005.tif']);
        $record = AnalysisRecord::first()->fresh();

        $this->assertNotEmpty(app(ResultEvidence::class)->listFor($record));

        $this->apiAs($this->token)
            ->deleteJson("/api/predictions/{$body['data']['id']}")
            ->assertOk();

        $this->assertEmpty(Storage::files(ResultEvidence::directoryFor($record)));
    }

    public function test_an_evidence_name_that_is_not_a_plain_png_is_refused(): void
    {
        $this->fakeWorkerReturnsFrames();

        $body = $this->upload(['frame_001.tif', 'frame_005.tif']);
        $id = $body['data']['id'];

        // Reaches the controller and is turned away there.
        $this->apiAs($this->token)
            ->get("/api/predictions/{$id}/evidence/config.php")
            ->assertStatus(422);

        // Traversal never even routes — the separator stops it before the
        // controller sees it. Asserting "not 200" rather than a specific code
        // keeps this a test of the outcome rather than of which layer said no.
        $traversal = $this->apiAs($this->token)
            ->get("/api/predictions/{$id}/evidence/" . urlencode('../../.env'));

        $this->assertNotSame(200, $traversal->status());
    }

    /**
     * A worker that refuses is a verdict; a worker that does not answer is a
     * machine that was asleep.
     *
     * The GPU is heading for a workstation on the lab network — one that
     * reboots for updates and gets used for other things. Failing a
     * researcher's job because a machine was unreachable for ninety seconds is
     * not a fault report, it is lost work.
     */
    public function test_a_worker_that_refuses_fails_the_job_at_once(): void
    {
        // The worker answered. It will answer the same way in two minutes, so
        // there is nothing to wait for.
        Http::fake([
            'worker.example/*' => Http::response(
                '{"error":"unsupported frame size"}',
                200,
                ['Content-Type' => 'application/json']
            ),
        ]);

        $this->upload(['frame_001.tif', 'frame_005.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertSame('failed', $record->status);
        $this->assertStringContainsString('unsupported frame size', $record->error_message);
    }

    public function test_an_unreachable_worker_is_not_treated_as_a_refusal(): void
    {
        // Nothing answered at all. Under `sync` the job cannot actually be
        // released back to a queue, so what is asserted here is the decision:
        // the failure is recognised as absence rather than rejection, and the
        // message says the platform intends to try again.
        Http::fake(function () {
            throw new ConnectionException('cURL error 7: Failed to connect');
        });

        $this->upload(['frame_001.tif', 'frame_005.tif']);

        $record = AnalysisRecord::first()->fresh();

        $this->assertNotSame(
            'completed',
            $record->status,
            'nothing was generated, so this cannot be a success'
        );
        $this->assertStringContainsString('not responding', $record->error_message ?? '');
    }

    public function test_provenance_is_returned_by_the_detail_endpoint(): void
    {
        $this->fakeWorkerReturnsFrames();

        $body = $this->upload(['frame_001.tif', 'frame_005.tif']);
        $id = $body['data']['id'];

        $this->apiAs($this->token)
            ->getJson("/api/predictions/{$id}")
            ->assertOk()
            ->assertJsonCount(3, 'data.frame_provenance')
            ->assertJsonPath('data.frame_provenance.1.index', 3)
            ->assertJsonPath('data.frame_provenance.1.generation', 1);
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

    /**
     * A job runs for minutes and nobody watches a progress bar that long, so
     * the notification is how the researcher finds out at all.
     */
    public function test_a_finished_job_notifies_its_owner(): void
    {
        $this->fakeWorkerReturnsFrames();

        $this->upload();

        $notification = $this->user->fresh()->notifications->first();

        $this->assertNotNull($notification, 'a completed job must notify its owner');
        $this->assertSame('prediction.completed', $notification->data['type']);
        $this->assertSame(
            'predictions/' . AnalysisRecord::first()->id,
            $notification->data['link'],
        );
    }

    public function test_a_failed_job_notifies_its_owner_with_the_reason(): void
    {
        Http::fake(['worker.example/*' => Http::response('gateway down', 502)]);

        $this->upload();

        $notification = $this->user->fresh()->notifications->first();

        $this->assertNotNull($notification, 'a failed job must notify its owner');
        $this->assertSame('prediction.failed', $notification->data['type']);
        $this->assertStringContainsString('502', $notification->data['body']);
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
            'name' => 'Other', 'email' => 'other@brin.go.id',
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

    public function test_the_frame_list_covers_inputs_and_outputs(): void
    {
        $this->fakeWorkerReturnsFrames();
        $this->upload();

        $record = AnalysisRecord::first();

        $frames = $this->apiAs($this->token)
            ->getJson("/api/predictions/{$record->id}/frames")
            ->assertOk()
            ->json('data');

        $names = array_column($frames, 'name');
        $kinds = array_count_values(array_column($frames, 'kind'));

        $this->assertContains('frame_001.tif', $names);
        $this->assertContains('frame_003.tif', $names);
        $this->assertSame(2, $kinds['input']);
        $this->assertSame(3, $kinds['output']);
    }

    public function test_a_frame_renders_as_a_png(): void
    {
        $this->fakeWorkerReturnsFrames();
        $this->upload();

        $record = AnalysisRecord::first();

        $response = $this->apiAs($this->token)
            ->get("/api/predictions/{$record->id}/frames/frame_003.tif/preview");

        $response->assertOk();
        $this->assertSame('image/png', $response->headers->get('Content-Type'));
        // Built from character codes: embedding the raw signature in source
        // is a good way to have an editor or tool quietly rewrite it.
        $signature = chr(0x89) . 'PNG' . chr(0x0D) . chr(0x0A) . chr(0x1A) . chr(0x0A);
        $this->assertSame($signature, substr($response->getContent(), 0, 8));
    }

    /** Rendering is cached beside the job so a gallery does not redo the work. */
    public function test_a_rendered_preview_is_cached(): void
    {
        $this->fakeWorkerReturnsFrames();
        $this->upload();

        $record = AnalysisRecord::first();

        $this->apiAs($this->token)
            ->get("/api/predictions/{$record->id}/frames/frame_003.tif/preview")
            ->assertOk();

        $cached = Storage::allFiles("{$record->storageDirectory()}/preview");
        $this->assertNotEmpty($cached);
    }

    /** A crafted name must not reach outside the job's own folders. */
    public function test_a_traversing_frame_name_is_rejected(): void
    {
        $this->fakeWorkerReturnsFrames();
        $this->upload();

        $record = AnalysisRecord::first();

        $this->apiAs($this->token)
            ->getJson("/api/predictions/{$record->id}/frames/" . urlencode('../../../.env') . '/preview')
            ->assertNotFound();
    }

    public function test_frames_of_another_account_are_not_listed(): void
    {
        $this->fakeWorkerReturnsFrames();
        $this->upload();

        User::create([
            'name' => 'Other', 'email' => 'other@brin.go.id',
            'password' => Hash::make('password123'), 'role' => 'user', 'is_active' => true,
        ]);
        $otherToken = $this->tokenFor('other@brin.go.id', 'password123');

        $record = AnalysisRecord::first();

        $this->apiAs($otherToken)
            ->getJson("/api/predictions/{$record->id}/frames")
            ->assertNotFound();
    }

    public function test_frames_are_gone_once_the_files_expire(): void
    {
        $this->fakeWorkerReturnsFrames();
        $this->upload();

        $record = AnalysisRecord::first();
        $record->update(['files_deleted_at' => now()]);

        $this->apiAs($this->token)
            ->getJson("/api/predictions/{$record->id}/frames")
            ->assertStatus(410);
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
