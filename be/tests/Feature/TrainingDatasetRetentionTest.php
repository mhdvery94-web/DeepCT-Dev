<?php

namespace Tests\Feature;

use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Training dataset archives have a retention window; they never had one.
 *
 * `predictions:cleanup` sweeps prediction output, `temp/downloads` and
 * abandoned `.part` files, and it has never touched `training/datasets` —
 * where a run leaves up to 512 MB behind. The only deletion was
 * `DELETE /admin/training/datasets/{id}`: manual, admin only. 219 MB had
 * accumulated on this machine by 2 September from fourteen datasets.
 *
 * THE WINDOW IS NOT MEASURED FROM UPLOAD
 * -------------------------------------
 * A dataset is reused between runs — that is the reason it is uploaded to the
 * platform rather than fetched per-run — so a clock that starts at upload
 * would delete something still in daily use. It runs from the *last time the
 * dataset was involved in anything* instead, and a dataset with a job still
 * queued or running is never swept at all, however old it is.
 *
 * The row survives. A training job points at its dataset, and deleting the row
 * would leave the run's history pointing at nothing — the same reason
 * `predictions:cleanup` stamps `files_deleted_at` rather than deleting the
 * record.
 */
class TrainingDatasetRetentionTest extends TestCase
{
    use RefreshDatabase;

    private User $researcher;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');

        config(['training.dataset_retention_days' => 30]);

        $this->researcher = User::create([
            'name' => 'Researcher', 'email' => 'researcher@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);
    }

    /** A dataset with an archive on disk, aged by hand. */
    private function dataset(int $daysOld, int $bytes = 2048): TrainingDataset
    {
        $path = 'training/datasets/' . uniqid() . '.zip';
        Storage::put($path, str_repeat('Z', $bytes));

        $dataset = TrainingDataset::create([
            'name' => 'Frames',
            'source_type' => 'upload',
            'archive_path' => $path,
            'size_bytes' => $bytes,
            'uploaded_by' => $this->researcher->id,
        ]);

        $dataset->forceFill(['created_at' => now()->subDays($daysOld)])->save();

        return $dataset->fresh();
    }

    private function job(TrainingDataset $dataset, string $status, int $daysOld): TrainingJob
    {
        $job = TrainingJob::create([
            'name' => 'Run',
            'training_dataset_id' => $dataset->id,
            'total_epochs' => 5,
            'status' => $status,
            'created_by' => $this->researcher->id,
        ]);

        $job->forceFill([
            'created_at' => now()->subDays($daysOld),
            'finished_at' => in_array($status, TrainingJob::FINISHED, true)
                ? now()->subDays($daysOld)
                : null,
        ])->save();

        return $job->fresh();
    }

    public function test_an_archive_past_the_window_is_deleted_and_the_row_kept(): void
    {
        $dataset = $this->dataset(daysOld: 40);
        $path = $dataset->archive_path;

        $this->artisan('training:cleanup')->assertSuccessful();

        Storage::assertMissing($path);

        $fresh = $dataset->fresh();
        $this->assertNotNull($fresh, 'the row must survive so a run keeps its history');
        $this->assertNotNull($fresh->archive_deleted_at);
        $this->assertSame($path, $fresh->archive_path, 'what was there is still recorded');
    }

    public function test_an_archive_inside_the_window_is_left_alone(): void
    {
        $dataset = $this->dataset(daysOld: 5);

        $this->artisan('training:cleanup')->assertSuccessful();

        Storage::assertExists($dataset->archive_path);
        $this->assertNull($dataset->fresh()->archive_deleted_at);
    }

    /**
     * The reason the window is not measured from upload.
     *
     * A dataset uploaded in January and trained against last week is in daily
     * use. Counting from its own `created_at` would delete it out from under
     * the person using it most.
     */
    public function test_a_dataset_used_recently_survives_however_old_it_is(): void
    {
        $dataset = $this->dataset(daysOld: 200);
        $this->job($dataset, 'completed', daysOld: 3);

        $this->artisan('training:cleanup')->assertSuccessful();

        Storage::assertExists($dataset->archive_path);
    }

    /** A worker is holding this one. Taking its source away mid-run is worse
     *  than any amount of disk. */
    public function test_a_dataset_with_a_running_job_is_never_swept(): void
    {
        $dataset = $this->dataset(daysOld: 400);
        $this->job($dataset, 'running', daysOld: 400);

        $this->artisan('training:cleanup')->assertSuccessful();

        Storage::assertExists($dataset->archive_path);
    }

    /** Queued counts too: it has not started, but it is going to. */
    public function test_a_dataset_with_a_queued_job_is_never_swept(): void
    {
        $dataset = $this->dataset(daysOld: 400);
        $this->job($dataset, 'queued', daysOld: 400);

        $this->artisan('training:cleanup')->assertSuccessful();

        Storage::assertExists($dataset->archive_path);
    }

    /** Rendered previews are derived from an archive that is now gone. */
    public function test_the_preview_cache_goes_with_the_archive(): void
    {
        $dataset = $this->dataset(daysOld: 40);
        $preview = "training/datasets/preview/{$dataset->id}/512_frame_001.tif.png";
        Storage::put($preview, 'png');

        $this->artisan('training:cleanup')->assertSuccessful();

        Storage::assertMissing($preview);
    }

    public function test_a_dry_run_deletes_nothing(): void
    {
        $dataset = $this->dataset(daysOld: 40);

        $this->artisan('training:cleanup --dry-run')->assertSuccessful();

        Storage::assertExists($dataset->archive_path);
        $this->assertNull($dataset->fresh()->archive_deleted_at);
    }

    /**
     * A swept dataset must say so.
     *
     * `archiveFrames()` returns an empty collection when the archive is not
     * on disk, so the frame list came back `[]` — indistinguishable from an
     * archive that genuinely holds no frames. This project has spent enough
     * days on screens that say nothing.
     */
    public function test_a_researcher_is_told_the_archive_is_gone(): void
    {
        $dataset = $this->dataset(daysOld: 40);
        $job = $this->job($dataset, 'completed', daysOld: 40);

        $this->artisan('training:cleanup')->assertSuccessful();

        $this->apiAs($this->tokenFor($this->researcher->email, 'password123'))
            ->getJson("/api/me/training/jobs/{$job->id}/dataset/frames")
            ->assertOk()
            ->assertJsonPath('meta.archive_deleted', true);
    }
}
