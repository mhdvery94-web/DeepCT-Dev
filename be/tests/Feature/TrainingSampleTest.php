<?php

namespace Tests\Feature;

use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\TrainingSample;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * One rendered frame per epoch, so a researcher can watch the model improve.
 */
class TrainingSampleTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;
    private User $stranger;
    private TrainingJob $job;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');

        config(['training.worker_token' => 'worker-token-for-tests']);

        $this->owner = User::create([
            'name' => 'Owner', 'email' => 'owner@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);

        $this->stranger = User::create([
            'name' => 'Stranger', 'email' => 'stranger@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);

        $dataset = TrainingDataset::create([
            'name' => 'Set',
            'source_type' => 'upload',
            'archive_path' => 'training/datasets/x.zip',
            'uploaded_by' => $this->owner->id,
        ]);

        $this->job = TrainingJob::create([
            'name' => 'Run',
            'training_dataset_id' => $dataset->id,
            'status' => 'running',
            'total_epochs' => 10,
            'created_by' => $this->owner->id,
        ]);
    }

    private function token(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    private function png(int $kilobytes = 8): UploadedFile
    {
        return UploadedFile::fake()->create('sample.png', $kilobytes, 'image/png');
    }

    private function sendSample(int $epoch, ?UploadedFile $file = null)
    {
        return $this->withHeader('X-Worker-Token', 'worker-token-for-tests')
            ->post("/api/training/worker/jobs/{$this->job->id}/sample", [
                'epoch' => $epoch,
                'image' => $file ?? $this->png(),
            ], ['Accept' => 'application/json']);
    }

    public function test_a_worker_can_send_one_sample_per_epoch(): void
    {
        $this->sendSample(3)->assertOk();

        $sample = TrainingSample::firstOrFail();
        $this->assertSame(3, $sample->epoch);
        $this->assertTrue(Storage::exists($sample->path));
    }

    /**
     * A worker that loses its connection and repeats an epoch is the normal
     * course of events here, so the second send replaces the first.
     */
    public function test_resending_an_epoch_replaces_it(): void
    {
        $this->sendSample(3)->assertOk();
        $first = TrainingSample::firstOrFail()->path;

        $this->sendSample(3)->assertOk();

        $this->assertSame(1, TrainingSample::count());
        $this->assertFalse(Storage::exists($first), 'the old file must go');
    }

    public function test_an_oversized_sample_is_refused(): void
    {
        $this->sendSample(3, $this->png(5 * 1024))->assertStatus(422);

        $this->assertSame(0, TrainingSample::count());
    }

    public function test_a_sample_without_a_worker_token_is_refused(): void
    {
        $this->post("/api/training/worker/jobs/{$this->job->id}/sample", [
            'epoch' => 1,
            'image' => $this->png(),
        ], ['Accept' => 'application/json'])->assertStatus(401);

        $this->assertSame(0, TrainingSample::count());
    }

    public function test_the_owner_lists_and_reads_its_samples(): void
    {
        $this->sendSample(1)->assertOk();
        $this->sendSample(2)->assertOk();

        $token = $this->token($this->owner);

        $this->apiAs($token)
            ->getJson("/api/me/training/jobs/{$this->job->id}/samples")
            ->assertOk()
            ->assertJsonPath('data.0.epoch', 1)
            ->assertJsonPath('data.1.epoch', 2);

        $this->apiAs($token)
            ->get("/api/me/training/jobs/{$this->job->id}/samples/1")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png');
    }

    public function test_someone_elses_samples_are_not_readable(): void
    {
        $this->sendSample(1)->assertOk();

        $this->apiAs($this->token($this->stranger))
            ->getJson("/api/me/training/jobs/{$this->job->id}/samples")
            ->assertNotFound();
    }

    /**
     * The foreign key cascades the rows on its own, but a database cascade
     * fires no model events — so without help the PNGs stay on disk forever
     * with nothing pointing at them.
     */
    public function test_deleting_a_job_deletes_its_sample_files(): void
    {
        $this->sendSample(1)->assertOk();
        $path = TrainingSample::firstOrFail()->path;

        $this->job->delete();

        $this->assertSame(0, TrainingSample::count());
        $this->assertFalse(Storage::exists($path));
    }
}
