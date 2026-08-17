<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\TrainingJob;
use App\Models\TrainingMetric;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Training, started by the person who has the data.
 *
 * The old shape had an administrator register the dataset and queue the job on
 * a researcher's behalf, which meant the researcher could not start anything.
 * These assertions pin the new shape: the researcher uploads and starts, the
 * platform keeps the numbers, and nobody else can read them.
 */
class ResearcherTrainingTest extends TestCase
{
    use RefreshDatabase;

    private const TOKEN = 'test-worker-token-0123456789';

    private User $researcher;
    private User $other;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('local');
        config([
            'training.worker_token' => self::TOKEN,
            'training.callback_url' => 'https://platform.example',
        ]);

        $this->researcher = $this->makeUser('researcher', 'researcher@brin.go.id');
        $this->other = $this->makeUser('someone', 'someone@brin.go.id');
    }

    private function makeUser(string $username, string $email): User
    {
        return User::create([
            'username' => $username,
            'name' => ucfirst($username),
            'email' => $email,
            'password' => Hash::make('password123'),
            'role' => 'user',
            'is_active' => true,
        ]);
    }

    private function token(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    private function archive(): UploadedFile
    {
        return UploadedFile::fake()->create('frames.zip', 64, 'application/zip');
    }

    /** Every job needs one; the column is not nullable. */
    private function makeDataset(User $owner): int
    {
        return \App\Models\TrainingDataset::create([
            'name' => 'Frames',
            'source_type' => 'url',
            'source_url' => 'https://example.org/dataset.zip',
            'uploaded_by' => $owner->id,
        ])->id;
    }

    private function registerTrainer(): Model
    {
        return Model::create([
            'name' => 'Kaggle trainer',
            'version' => 'v1',
            'kind' => 'trainer',
            'endpoint_url' => 'https://trainer.example/train',
            'status' => 'online',
            'is_active' => true,
            'max_concurrent_jobs' => 1,
        ]);
    }

    public function test_a_researcher_starts_their_own_run(): void
    {
        Http::fake(['*' => Http::response(['accepted' => true], 200)]);
        $trainer = $this->registerTrainer();

        $response = $this->apiAs($this->token($this->researcher))
            ->post('/api/me/training/jobs', [
                'name' => 'Balanced-t retrain',
                'total_epochs' => 10,
                'archive' => $this->archive(),
            ], ['Accept' => 'application/json'])
            ->assertStatus(201);

        $job = TrainingJob::firstOrFail();

        $this->assertSame($this->researcher->id, $job->created_by);
        // Still queued after a successful push: the trainer said it *accepted*
        // the job, and only its first heartbeat proves it started.
        $this->assertSame('queued', $job->status);
        $this->assertSame($trainer->id, $job->trainer_model_id);
        $response->assertJsonPath('data.trainer.name', 'Kaggle trainer');
    }

    /** No trainer registered is not a failed request — the run is recorded. */
    public function test_a_run_is_queued_even_with_no_trainer_available(): void
    {
        $response = $this->apiAs($this->token($this->researcher))
            ->post('/api/me/training/jobs', [
                'name' => 'No trainer yet',
                'total_epochs' => 3,
                'archive' => $this->archive(),
            ], ['Accept' => 'application/json'])
            ->assertStatus(201);

        $this->assertSame('queued', TrainingJob::firstOrFail()->status);
        // ...but it says why nothing is moving, rather than sitting silent.
        $this->assertNotNull($response->json('dispatch_message'));
    }

    /**
     * The large-dataset path: the same resumable session a prediction upload
     * uses, told what the archive is for.
     */
    public function test_a_dataset_can_arrive_in_chunks(): void
    {
        $token = $this->token($this->researcher);
        $body = str_repeat('D', 2048);

        $start = $this->apiAs($token)->postJson('/api/predictions/uploads', [
            'purpose' => 'training',
            'name' => 'Chunked retrain',
            'total_epochs' => 4,
            'total_size' => strlen($body),
            'filename' => 'frames.zip',
        ])->assertCreated();

        $uploadId = $start->json('data.upload_id');

        // A chunk is a multipart part, not a raw body — `PATCH` with a file
        // field, which Laravel's test client sends as a spoofed POST.
        foreach ([0, 1024] as $offset) {
            $part = tempnam(sys_get_temp_dir(), 'chunk');
            file_put_contents($part, substr($body, $offset, 1024));

            $this->apiAs($token)->post(
                "/api/predictions/uploads/{$uploadId}",
                [
                    '_method' => 'PATCH',
                    'offset' => $offset,
                    'chunk' => new UploadedFile($part, 'chunk.bin', 'application/octet-stream', null, true),
                ],
                ['Accept' => 'application/json'],
            )->assertOk();
        }

        $this->apiAs($token)
            ->postJson("/api/predictions/uploads/{$uploadId}/finalize")
            ->assertCreated()
            ->assertJsonPath('data.name', 'Chunked retrain');

        $job = TrainingJob::firstOrFail();
        $this->assertSame($this->researcher->id, $job->created_by);
        $this->assertSame(4, $job->total_epochs);
        // Moved rather than copied: a training set is the largest thing here.
        $this->assertNotNull($job->dataset->archive_path);
        Storage::assertExists($job->dataset->archive_path);
    }

    public function test_a_researcher_cannot_read_someone_elses_run(): void
    {
        $job = TrainingJob::create([
            'name' => 'Private', 'training_dataset_id' => $this->makeDataset($this->other),
            'total_epochs' => 5, 'status' => 'queued',
            'created_by' => $this->other->id,
        ]);

        // 404, not 403: confirming that a run exists is itself a leak.
        $this->apiAs($this->token($this->researcher))
            ->getJson("/api/me/training/jobs/{$job->id}")
            ->assertNotFound();

        $this->apiAs($this->token($this->researcher))
            ->getJson('/api/me/training/jobs')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    /**
     * The whole point of keeping the history: one number says how it is doing,
     * a series says whether it learned anything.
     */
    public function test_the_run_carries_its_metric_history(): void
    {
        $job = TrainingJob::create([
            'name' => 'Retrain', 'training_dataset_id' => $this->makeDataset($this->researcher),
            'total_epochs' => 3, 'current_epoch' => 2, 'status' => 'running',
            'created_by' => $this->researcher->id,
        ]);

        TrainingMetric::record($job->id, 1, ['loss' => 0.42, 'psnr' => 24.1]);
        TrainingMetric::record($job->id, 2, ['loss' => 0.31, 'psnr' => 26.8]);

        $response = $this->apiAs($this->token($this->researcher))
            ->getJson("/api/me/training/jobs/{$job->id}")
            ->assertOk();

        $response->assertJsonCount(2, 'data.history');
        $response->assertJsonPath('data.history.0.epoch', 1);
        $response->assertJsonPath('data.history.1.metrics.loss', 0.31);
    }

    /** Heartbeats repeat within an epoch; the curve must not grow a step each time. */
    public function test_repeated_reports_for_one_epoch_do_not_duplicate(): void
    {
        $job = TrainingJob::create([
            'name' => 'Retrain', 'training_dataset_id' => $this->makeDataset($this->researcher),
            'total_epochs' => 3, 'status' => 'running',
            'created_by' => $this->researcher->id,
        ]);

        TrainingMetric::record($job->id, 1, ['loss' => 0.5]);
        TrainingMetric::record($job->id, 1, ['loss' => 0.4]);

        $this->assertSame(1, TrainingMetric::where('training_job_id', $job->id)->count());
        $this->assertSame(0.4, TrainingMetric::first()->metrics['loss']);
    }

    public function test_a_researcher_cancels_their_own_run(): void
    {
        $job = TrainingJob::create([
            'name' => 'Retrain', 'training_dataset_id' => $this->makeDataset($this->researcher),
            'total_epochs' => 3, 'status' => 'running',
            'created_by' => $this->researcher->id,
        ]);

        $this->apiAs($this->token($this->researcher))
            ->postJson("/api/me/training/jobs/{$job->id}/cancel")
            ->assertOk();

        $this->assertSame('cancelled', $job->fresh()->status);

        // Twice is a conflict, not a second cancellation.
        $this->apiAs($this->token($this->researcher))
            ->postJson("/api/me/training/jobs/{$job->id}/cancel")
            ->assertStatus(409);
    }

    /**
     * A trainer endpoint in the model picker would offer a researcher something
     * that cannot interpolate a frame.
     */
    public function test_trainers_never_appear_as_prediction_models(): void
    {
        $this->registerTrainer();

        Model::create([
            'name' => 'deepCT', 'version' => 'v1',
            'endpoint_url' => 'https://model.example/predict',
            'status' => 'online', 'is_active' => true, 'max_concurrent_jobs' => 1,
        ]);

        $response = $this->apiAs($this->token($this->researcher))
            ->getJson('/api/me/models')
            ->assertOk();

        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.name', 'deepCT');
    }
}
