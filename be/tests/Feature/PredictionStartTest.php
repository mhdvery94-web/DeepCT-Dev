<?php

namespace Tests\Feature;

use App\Jobs\ProcessDeepLearningImage;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Upload and analysis are two steps.
 *
 * A researcher asked to see the frames before committing a run to a GPU that
 * is not always up, so an upload now lands as `uploaded` and stays there until
 * someone presses START.
 */
class PredictionStartTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;
    private User $stranger;
    private Model $model;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');

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

        $this->model = Model::create([
            'name' => 'deepCT TC-D', 'version' => 'v1', 'kind' => 'inference',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online', 'is_active' => true,
        ]);
    }

    private function record(array $overrides = []): AnalysisRecord
    {
        return AnalysisRecord::create(array_merge([
            'user_id' => $this->owner->id,
            'job_id' => 'job-' . uniqid(),
            'model_id' => $this->model->id,
            'file_name' => 'frames.zip',
            'input_folder' => 'predictions/1/job/input',
            'output_folder' => 'predictions/1/job/output',
            'status' => 'uploaded',
            'input_files_count' => 2,
            'expires_at' => now()->addHours(24),
        ], $overrides));
    }

    private function token(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    public function test_starting_queues_the_job_and_moves_it_to_pending(): void
    {
        Bus::fake();
        $record = $this->record();

        $this->apiAs($this->token($this->owner))
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertOk()
            ->assertJsonPath('data.status', 'pending');

        $this->assertSame('pending', $record->fresh()->status);
        Bus::assertDispatched(ProcessDeepLearningImage::class);
    }

    /**
     * A double tap on a phone must not queue the work twice — the same job
     * running on two workers would write over its own output folder.
     */
    public function test_starting_twice_is_refused_and_queues_once(): void
    {
        Bus::fake();
        $record = $this->record();
        $token = $this->token($this->owner);

        $this->apiAs($token)
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertOk();

        $this->apiAs($token)
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertStatus(409);

        Bus::assertDispatchedTimes(ProcessDeepLearningImage::class, 1);
    }

    /**
     * 404 rather than 403: a stranger must not learn that the record exists.
     * Matches findOwned(), which every other prediction route uses.
     */
    public function test_someone_elses_upload_cannot_be_started(): void
    {
        Bus::fake();
        $record = $this->record();

        $this->apiAs($this->token($this->stranger))
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertNotFound();

        Bus::assertNothingDispatched();
    }

    public function test_an_expired_upload_cannot_be_started(): void
    {
        Bus::fake();
        $record = $this->record(['files_deleted_at' => now()->subMinute()]);

        $this->apiAs($this->token($this->owner))
            ->postJson("/api/predictions/{$record->id}/start")
            ->assertStatus(410);

        Bus::assertNothingDispatched();
    }
}
