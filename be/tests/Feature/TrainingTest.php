<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Managed model training.
 *
 * The assertions that matter are the ones about a worker **dying**: a Kaggle
 * session lasts 9–12 hours and training takes days, so a worker disappearing
 * mid-run is the normal course of events. A job that failed permanently every
 * time that happened would never finish a multi-day training.
 */
class TrainingTest extends TestCase
{
    use RefreshDatabase;

    private const TOKEN = 'test-worker-token-0123456789';

    private User $admin;
    private User $researcher;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('local');
        config(['training.worker_token' => self::TOKEN]);

        $this->admin = $this->makeUser('admin', 'admin@brin.go.id', 'admin');
        $this->researcher = $this->makeUser('researcher', 'researcher@brin.go.id', 'user');
    }

    private function makeUser(string $name, string $email, string $role): User
    {
        return User::create([
            'name' => ucfirst($name),
            'email' => $email,
            'password' => Hash::make('password123'),
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function adminToken(): string
    {
        return $this->tokenFor($this->admin->email, 'password123');
    }

    /** A request as the GPU worker, which uses a shared secret, not a session. */
    private function asWorker(): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withHeader('Authorization', 'Bearer ' . self::TOKEN);
    }

    private function postForm(string $uri, array $data = [])
    {
        return $this->post($uri, $data, ['Accept' => 'application/json']);
    }

    private function makeDataset(array $overrides = []): TrainingDataset
    {
        return TrainingDataset::create(array_merge([
            'name' => 'Balanced-t neutron frames',
            'source_type' => 'url',
            'source_url' => 'https://example.org/dataset.zip',
            'uploaded_by' => $this->admin->id,
        ], $overrides));
    }

    private function makeJob(array $overrides = []): TrainingJob
    {
        return TrainingJob::create(array_merge([
            'name' => 'Retrain on balanced t',
            'training_dataset_id' => $this->makeDataset()->id,
            'total_epochs' => 100,
            'status' => 'queued',
            'created_by' => $this->admin->id,
        ], $overrides));
    }

    private function weightsFile(string $name = 'weights.h5'): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'w') . '.h5';
        file_put_contents($path, str_repeat('W', 2048));

        return new UploadedFile($path, $name, 'application/octet-stream', null, true);
    }

    // ------------------------------------------------------------ datasets

    public function test_an_admin_can_register_a_dataset_by_url(): void
    {
        // The realistic case: a 20 GB dataset should never travel up a home
        // tunnel and back down to Kaggle.
        $this->apiAs($this->adminToken())
            ->postJson('/api/admin/training/datasets', [
                'name' => 'Balanced-t frames',
                'source_type' => 'url',
                'source_url' => 'https://example.org/frames.zip',
            ])
            ->assertCreated()
            ->assertJsonPath('data.source_type', 'url');

        $this->assertSame(1, TrainingDataset::count());
    }

    public function test_a_url_dataset_needs_a_url(): void
    {
        $this->apiAs($this->adminToken())
            ->postJson('/api/admin/training/datasets', [
                'name' => 'Nowhere',
                'source_type' => 'url',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['source_url']);
    }

    /**
     * An administrator registers where data already lives; they do not carry
     * it. Pushing 20 GB up a home tunnel so the GPU host can pull it back down
     * is absurd when the worker can fetch it directly, and uploading is the
     * researcher's path anyway — chunked, resumable, and theirs.
     */
    public function test_an_admin_cannot_upload_a_dataset(): void
    {
        $path = tempnam(sys_get_temp_dir(), 'ds') . '.zip';
        file_put_contents($path, "PK\x03\x04" . str_repeat('D', 512));

        $this->apiAs($this->adminToken())
            ->postForm('/api/admin/training/datasets', [
                'name' => 'Small set',
                'archive' => new UploadedFile($path, 'set.zip', 'application/zip', null, true),
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['source_url']);

        $this->assertSame(0, TrainingDataset::count());
    }

    public function test_a_dataset_in_use_cannot_be_deleted(): void
    {
        $job = $this->makeJob();

        $this->apiAs($this->adminToken())
            ->deleteJson("/api/admin/training/datasets/{$job->training_dataset_id}")
            ->assertStatus(409);

        $this->assertSame(1, TrainingDataset::count());
    }

    // ---------------------------------------------------------------- jobs

    /**
     * Queueing a run is the researcher's, and only the researcher's.
     *
     * An administrator arranging runs on someone's behalf was the whole shape
     * this system was turned away from; leaving the endpoint in place would
     * have left two ways to do one thing, differing only in who is recorded as
     * having started it.
     */
    public function test_an_admin_can_no_longer_queue_a_job(): void
    {
        $dataset = $this->makeDataset();

        $this->apiAs($this->adminToken())
            ->postJson('/api/admin/training/jobs', [
                'name' => 'Retrain on balanced t',
                'training_dataset_id' => $dataset->id,
                'total_epochs' => 200,
            ])
            // 405 rather than 404: `GET /training/jobs` still lives at this
            // path, so the route exists and the verb does not.
            ->assertStatus(405);

        $this->assertSame(0, TrainingJob::count());
    }

    public function test_a_researcher_cannot_reach_training_at_all(): void
    {
        $job = $this->makeJob();
        $token = $this->tokenFor($this->researcher->email, 'password123');

        $this->apiAs($token)->getJson('/api/admin/training/jobs')->assertForbidden();
        $this->apiAs($token)->getJson('/api/admin/training/datasets')->assertForbidden();
        $this->apiAs($token)
            ->postJson("/api/admin/training/jobs/{$job->id}/cancel")
            ->assertForbidden();
    }

    public function test_the_queue_reports_whether_a_worker_is_configured(): void
    {
        // Nothing moves while this is false and jobs are queued, which is the
        // first thing to check when a job "does nothing".
        config(['training.worker_token' => null]);

        $this->apiAs($this->adminToken())
            ->getJson('/api/admin/training/jobs')
            ->assertOk()
            ->assertJsonPath('meta.worker_configured', false);
    }

    // -------------------------------------------------------- worker auth

    public function test_a_worker_without_the_token_gets_nothing(): void
    {
        $this->apiAs(null)
            ->postJson('/api/training/worker/claim')
            ->assertUnauthorized();
    }

    public function test_a_wrong_worker_token_is_refused(): void
    {
        $this->apiAs(null)
            ->withHeader('Authorization', 'Bearer not-the-token')
            ->postJson('/api/training/worker/claim')
            ->assertUnauthorized();
    }

    public function test_worker_routes_fail_closed_when_unconfigured(): void
    {
        // A half-configured deployment must refuse rather than accept anyone.
        config(['training.worker_token' => null]);

        $this->apiAs(null)
            ->withHeader('Authorization', 'Bearer anything')
            ->postJson('/api/training/worker/claim')
            ->assertStatus(503);
    }

    public function test_a_user_token_is_not_a_worker_token(): void
    {
        $this->apiAs($this->adminToken())
            ->postJson('/api/training/worker/claim')
            ->assertUnauthorized();
    }

    // ---------------------------------------------------------- the protocol

    public function test_a_worker_claims_the_oldest_queued_job(): void
    {
        $first = $this->makeJob(['name' => 'First']);
        $this->makeJob(['name' => 'Second']);

        $response = $this->asWorker()
            ->postJson('/api/training/worker/claim', ['worker_label' => 'kaggle-t4-1'])
            ->assertOk();

        $this->assertSame($first->id, $response->json('data.id'));
        $this->assertSame('claimed', $first->fresh()->status);
        $this->assertSame('kaggle-t4-1', $first->fresh()->worker_label);
    }

    public function test_claiming_an_empty_queue_is_not_an_error(): void
    {
        // The worker polls; "nothing to do" is the normal answer.
        $this->asWorker()
            ->postJson('/api/training/worker/claim')
            ->assertOk()
            ->assertJsonPath('data', null);
    }

    public function test_a_claimed_job_is_not_offered_twice(): void
    {
        $this->makeJob();

        $this->asWorker()->postJson('/api/training/worker/claim')->assertOk();

        $this->asWorker()
            ->postJson('/api/training/worker/claim')
            ->assertOk()
            ->assertJsonPath('data', null);
    }

    public function test_a_heartbeat_records_progress(): void
    {
        $job = $this->makeJob();
        $this->asWorker()->postJson('/api/training/worker/claim');

        $this->asWorker()
            ->postJson("/api/training/worker/jobs/{$job->id}/heartbeat", [
                'current_epoch' => 12,
                'metrics' => ['loss' => 0.031, 'psnr' => 34.2],
            ])
            ->assertOk()
            ->assertJsonPath('data.continue', true);

        $fresh = $job->fresh();
        $this->assertSame('running', $fresh->status);
        $this->assertSame(12, $fresh->current_epoch);
        $this->assertSame(0.031, $fresh->metrics['loss']);
    }

    public function test_a_cancelled_job_tells_the_worker_to_stop(): void
    {
        // Otherwise it would burn hours of GPU time on work nobody wants.
        $job = $this->makeJob(['status' => 'cancelled']);

        $this->asWorker()
            ->postJson("/api/training/worker/jobs/{$job->id}/heartbeat", [
                'current_epoch' => 5,
            ])
            ->assertOk()
            ->assertJsonPath('data.continue', false);
    }

    public function test_a_checkpoint_is_stored_and_replaces_the_last_one(): void
    {
        $job = $this->makeJob();

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/checkpoint",
            ['current_epoch' => 10, 'weights' => $this->weightsFile('e10.h5')],
        )->assertOk();

        $first = $job->fresh()->checkpoint_path;
        $this->assertNotNull($first);
        Storage::assertExists($first);

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/checkpoint",
            ['current_epoch' => 20, 'weights' => $this->weightsFile('e20.h5')],
        )->assertOk();

        $second = $job->fresh()->checkpoint_path;
        $this->assertNotSame($first, $second);
        Storage::assertMissing($first);
        Storage::assertExists($second);
        $this->assertSame(20, $job->fresh()->current_epoch);
    }

    public function test_a_dead_worker_returns_the_job_to_the_queue(): void
    {
        // The centre of the whole design. A Kaggle session ending is normal,
        // not a failure, and the checkpoint is what the next worker resumes
        // from.
        $job = $this->makeJob();

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/checkpoint",
            ['current_epoch' => 40, 'weights' => $this->weightsFile()],
        )->assertOk();

        $checkpoint = $job->fresh()->checkpoint_path;

        // The session dies: no heartbeat since well before the window.
        $job->fresh()->update([
            'heartbeat_at' => now()->subMinutes(TrainingJob::STALE_AFTER_MINUTES + 5),
        ]);

        $this->artisan('training:reclaim')->assertSuccessful();

        $reclaimed = $job->fresh();
        $this->assertSame('queued', $reclaimed->status);
        $this->assertNull($reclaimed->worker_label);
        $this->assertSame(40, $reclaimed->current_epoch, 'progress must survive');
        $this->assertSame($checkpoint, $reclaimed->checkpoint_path);
        Storage::assertExists($checkpoint);
    }

    public function test_the_next_worker_is_told_where_to_resume(): void
    {
        $job = $this->makeJob(['current_epoch' => 40, 'checkpoint_path' => 'training/checkpoints/x.h5']);

        $response = $this->asWorker()
            ->postJson('/api/training/worker/claim')
            ->assertOk();

        $this->assertSame(40, $response->json('data.resume_from_epoch'));
        $this->assertTrue($response->json('data.has_checkpoint'));
    }

    public function test_a_busy_worker_is_not_reclaimed(): void
    {
        // A long epoch is not a dead session; taking the job away would waste
        // the GPU time already spent.
        $job = $this->makeJob(['status' => 'running', 'heartbeat_at' => now()->subMinute()]);

        $this->artisan('training:reclaim')->assertSuccessful();

        $this->assertSame('running', $job->fresh()->status);
    }

    public function test_completing_stores_the_weights_and_drops_the_checkpoint(): void
    {
        $job = $this->makeJob();

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/checkpoint",
            ['current_epoch' => 90, 'weights' => $this->weightsFile()],
        )->assertOk();
        $checkpoint = $job->fresh()->checkpoint_path;

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/complete",
            ['weights' => $this->weightsFile('final.h5'), 'metrics' => ['accuracy' => 93.5]],
        )->assertOk();

        $done = $job->fresh();
        $this->assertSame('completed', $done->status);
        $this->assertNotNull($done->weights_path);
        Storage::assertExists($done->weights_path);
        Storage::assertMissing($checkpoint);
        $this->assertSame(100, $done->current_epoch);
    }

    public function test_a_worker_can_report_a_real_failure(): void
    {
        $job = $this->makeJob();

        $this->asWorker()
            ->postJson("/api/training/worker/jobs/{$job->id}/fail", [
                'message' => 'CUDA out of memory at batch size 8',
            ])
            ->assertOk();

        $failed = $job->fresh();
        $this->assertSame('failed', $failed->status);
        $this->assertStringContainsString('CUDA', $failed->error_message);
    }

    public function test_a_finished_job_refuses_more_weights(): void
    {
        $job = $this->makeJob(['status' => 'completed', 'finished_at' => now()]);

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/complete",
            ['weights' => $this->weightsFile()],
        )->assertStatus(409);
    }

    // --------------------------------------------------------- registering

    public function test_finished_weights_can_become_a_model_version(): void
    {
        $job = $this->makeJob();

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/complete",
            ['weights' => $this->weightsFile(), 'metrics' => ['accuracy' => 93.5]],
        )->assertOk();

        $this->apiAs($this->adminToken())
            ->postJson("/api/admin/training/jobs/{$job->id}/register-model", [
                'name' => 'deepCT TC-D',
                'version' => 'v2.0',
            ])
            ->assertCreated();

        $model = Model::firstOrFail();
        $this->assertSame('v2.0', $model->version);
        $this->assertSame($job->fresh()->weights_path, $model->file_path);
        $this->assertSame(93.5, (float) $model->accuracy);

        // Inactive and offline: weights are a file, a model here is a running
        // worker with a URL. Nothing in this platform can deploy a .h5 to a
        // GPU, and pretending otherwise breaks the next prediction instead.
        $this->assertFalse((bool) $model->is_active);
        $this->assertSame('offline', $model->status);
        $this->assertNull($model->endpoint_url);
    }

    public function test_an_unfinished_job_has_nothing_to_register(): void
    {
        $job = $this->makeJob(['status' => 'running']);

        $this->apiAs($this->adminToken())
            ->postJson("/api/admin/training/jobs/{$job->id}/register-model", [
                'name' => 'Too soon',
                'version' => 'v2.0',
            ])
            ->assertStatus(409);
    }

    public function test_the_same_weights_are_not_registered_twice(): void
    {
        $job = $this->makeJob();

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/complete",
            ['weights' => $this->weightsFile()],
        )->assertOk();

        $payload = ['name' => 'deepCT TC-D', 'version' => 'v2.0'];

        $this->apiAs($this->adminToken())
            ->postJson("/api/admin/training/jobs/{$job->id}/register-model", $payload)
            ->assertCreated();

        $this->apiAs($this->adminToken())
            ->postJson("/api/admin/training/jobs/{$job->id}/register-model", $payload)
            ->assertStatus(409);

        $this->assertSame(1, Model::count());
    }

    public function test_cancelling_a_job_a_worker_holds(): void
    {
        $job = $this->makeJob();
        $this->asWorker()->postJson('/api/training/worker/claim')->assertOk();

        $this->apiAs($this->adminToken())
            ->postJson("/api/admin/training/jobs/{$job->id}/cancel")
            ->assertOk();

        $this->assertSame('cancelled', $job->fresh()->status);
    }

    // -------------------------------------------- the name the weights keep

    /**
     * A worker posts an `.h5` and gets back a suffix nobody chose.
     *
     * `store()` derives the extension from the MIME type, and a trainer
     * uploading with `application/octet-stream` had its weights land as
     * **`.bin`** on 17 August and **`.hdf`** on 29 August — 87,8 MB of a run
     * that had trained perfectly. Keras 3 picks its loader from the suffix and
     * knows neither, so an administrator downloading those weights could not
     * load them, and the name that would have worked was recorded nowhere.
     */
    public function test_stored_weights_keep_the_extension_the_worker_sent(): void
    {
        $job = $this->makeJob();

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/checkpoint",
            ['current_epoch' => 10, 'weights' => $this->weightsFile('epoch-10.h5')],
        )->assertOk();

        $this->assertStringEndsWith('.h5', $job->fresh()->checkpoint_path);

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/complete",
            ['weights' => $this->weightsFile('generator.weights.h5')],
        )->assertOk();

        $this->assertStringEndsWith('.h5', $job->fresh()->weights_path);
    }

    /** Keeping the client's extension must not let the client pick the path. */
    public function test_a_weights_filename_cannot_choose_where_it_lands(): void
    {
        $job = $this->makeJob();

        $this->asWorker()->postForm(
            "/api/training/worker/jobs/{$job->id}/complete",
            ['weights' => $this->weightsFile('../../../public/evil.php')],
        )->assertOk();

        $path = $job->fresh()->weights_path;

        $this->assertStringStartsWith('training/weights/', $path);
        $this->assertStringNotContainsString('..', $path);

        // Not a suffix any weights file uses, so it falls back to what the
        // MIME guess produced before — inside the directory, and inert.
        $this->assertStringEndsWith('.bin', $path);
    }

    /**
     * The claim payload is JSON the Python worker parses.
     *
     * Fifth outing for this family: PHP has one array type, `json_encode`
     * writes the empty one as `[]`, and a Pydantic model declaring a dict
     * rejects a list outright. `TrainerDispatcher` learned this in 1.29.0 and
     * the claim endpoint beside it never did.
     */
    public function test_a_claimed_job_carries_hyperparameters_as_an_object(): void
    {
        $this->makeJob();

        $response = $this->asWorker()->postJson('/api/training/worker/claim')->assertOk();

        $this->assertStringContainsString('"hyperparameters":{}', $response->getContent());
        $this->assertStringNotContainsString('"hyperparameters":[]', $response->getContent());
    }
}
