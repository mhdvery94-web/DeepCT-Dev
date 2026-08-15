<?php

namespace Tests\Feature;

use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * The 24-hour retention window, and the housekeeping around it.
 *
 * One job can produce ~1.5 GB, so anything this command fails to sweep sits on
 * disk forever. That is exactly the bug these tests were written after: the
 * temp sweeps used to sit behind an early return, so on an installation where
 * nothing had expired yet, abandoned uploads were never cleaned at all.
 */
class PredictionCleanupTest extends TestCase
{
    use RefreshDatabase;

    private User $user;
    private Model $model;

    protected function setUp(): void
    {
        parent::setUp();

        // Writes go to a temporary disk. RefreshDatabase rolls back the
        // database but leaves the filesystem alone, so without this every run
        // would leave real frames behind in storage/app/private/predictions.
        Storage::fake('local');

        $this->user = User::create([
            'username' => 'researcher', 'name' => 'Researcher',
            'email' => 'researcher@brin.go.id', 'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);

        $this->model = Model::create([
            'name' => 'M', 'version' => 'v1',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online', 'is_active' => true, 'max_concurrent_jobs' => 1,
        ]);
    }

    private function makeRecord(array $overrides = []): AnalysisRecord
    {
        $jobId = $overrides['job_id'] ?? 'job-' . uniqid();

        $record = AnalysisRecord::create(array_merge([
            'user_id' => $this->user->id,
            'model_id' => $this->model->id,
            'job_id' => $jobId,
            'input_folder' => "predictions/{$this->user->id}/{$jobId}/input",
            'output_folder' => "predictions/{$this->user->id}/{$jobId}/output",
            'status' => 'completed',
            'input_files_count' => 2,
            'output_files_count' => 3,
            'expires_at' => now()->addHours(24),
        ], $overrides));

        Storage::put("{$record->input_folder}/frame_001.tif", 'input bytes');
        Storage::put("{$record->output_folder}/frame_002.tif", 'output bytes');

        return $record;
    }

    public function test_expired_files_are_deleted_but_the_record_is_kept(): void
    {
        $record = $this->makeRecord(['expires_at' => now()->subHour()]);

        $this->artisan('predictions:cleanup')->assertSuccessful();

        $this->assertEmpty(Storage::allFiles($record->storageDirectory()));

        $record->refresh();
        $this->assertNotNull($record, 'the history entry must survive');
        $this->assertNotNull($record->files_deleted_at);
        $this->assertSame('completed', $record->status);
    }

    public function test_files_inside_the_window_are_left_alone(): void
    {
        $record = $this->makeRecord(['expires_at' => now()->addHours(5)]);

        $this->artisan('predictions:cleanup')->assertSuccessful();

        $this->assertNotEmpty(Storage::allFiles($record->storageDirectory()));
        $this->assertNull($record->fresh()->files_deleted_at);
    }

    public function test_dry_run_changes_nothing(): void
    {
        $record = $this->makeRecord(['expires_at' => now()->subHour()]);

        $this->artisan('predictions:cleanup --dry-run')->assertSuccessful();

        $this->assertNotEmpty(Storage::allFiles($record->storageDirectory()));
        $this->assertNull($record->fresh()->files_deleted_at);
    }

    public function test_an_already_swept_record_is_not_processed_twice(): void
    {
        $this->makeRecord([
            'expires_at' => now()->subHour(),
            'files_deleted_at' => now()->subMinutes(30),
        ]);

        $this->artisan('predictions:cleanup')
            ->expectsOutputToContain('Found 0 expired prediction(s).')
            ->assertSuccessful();
    }

    /**
     * The regression this suite exists for: with nothing expired, the command
     * used to return before ever reaching the temp sweeps.
     */
    public function test_abandoned_uploads_are_swept_even_when_nothing_expired(): void
    {
        $this->assertSame(0, AnalysisRecord::count());

        Storage::put("temp/uploads/{$this->user->id}/abandoned.part", str_repeat('x', 4096));
        Storage::put("temp/uploads/{$this->user->id}/abandoned.json", '{}');

        $this->ageFiles("temp/uploads/{$this->user->id}", days: 2);

        $this->artisan('predictions:cleanup')->assertSuccessful();

        $this->assertEmpty(
            Storage::allFiles("temp/uploads/{$this->user->id}"),
            'abandoned sessions must be swept regardless of expired records'
        );
    }

    /** Resuming an interrupted upload is supported, so recent sessions stay. */
    public function test_a_recent_upload_session_is_not_swept(): void
    {
        Storage::put("temp/uploads/{$this->user->id}/inflight.part", 'still going');

        $this->artisan('predictions:cleanup')->assertSuccessful();

        $this->assertNotEmpty(Storage::allFiles("temp/uploads/{$this->user->id}"));
    }

    public function test_orphaned_download_archives_are_swept(): void
    {
        Storage::put("temp/downloads/{$this->user->id}/results_old.zip", str_repeat('z', 2048));
        $this->ageFiles("temp/downloads/{$this->user->id}", days: 1);

        $this->artisan('predictions:cleanup')->assertSuccessful();

        $this->assertEmpty(Storage::allFiles("temp/downloads/{$this->user->id}"));
    }

    public function test_a_fresh_download_archive_is_left_alone(): void
    {
        Storage::put("temp/downloads/{$this->user->id}/results_new.zip", 'just built');

        $this->artisan('predictions:cleanup')->assertSuccessful();

        $this->assertNotEmpty(Storage::allFiles("temp/downloads/{$this->user->id}"));
    }

    /** Backdate every file in a directory so age-based sweeps consider it. */
    private function ageFiles(string $directory, int $days): void
    {
        $when = now()->subDays($days)->getTimestamp();

        foreach (Storage::allFiles($directory) as $file) {
            touch(Storage::path($file), $when);
        }
    }
}
