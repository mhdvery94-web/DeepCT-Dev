<?php

namespace Tests\Feature;

use App\Models\AnalysisRecord;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class StorageManagementTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $researcher;
    private string $adminToken;
    private string $userToken;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        $this->admin = User::create(['name' => 'Admin', 'email' => 'admin@storage.test', 'password' => bcrypt('test-password'), 'role' => 'admin', 'is_active' => true]);
        $this->researcher = User::create(['name' => 'Researcher', 'email' => 'user@storage.test', 'password' => bcrypt('test-password'), 'role' => 'user', 'is_active' => true]);
        $this->adminToken = $this->admin->createToken('test')->plainTextToken;
        $this->userToken = $this->researcher->createToken('test')->plainTextToken;
    }

    private function prediction(string $status): AnalysisRecord
    {
        $record = AnalysisRecord::create(['user_id' => $this->researcher->id, 'job_id' => (string) \Illuminate\Support\Str::uuid(), 'file_name' => 'frames.zip', 'status' => $status, 'expires_at' => now()->addDay()]);
        Storage::put($record->storageDirectory() . '/input/frame.tif', 'original frame');
        Storage::put("prediction-evidence/{$record->user_id}/{$record->job_id}/thumbnail.png", 'kept evidence');
        return $record;
    }

    public function test_only_admins_can_inspect_or_clean_application_storage(): void
    {
        $record = $this->prediction('completed');
        $this->apiAs(null)->getJson('/api/admin/storage')->assertUnauthorized();
        $this->apiAs($this->userToken)->getJson('/api/admin/storage')->assertForbidden();
        $this->apiAs($this->userToken)->postJson('/api/admin/storage/cleanup')->assertForbidden();
        $this->apiAs($this->userToken)->postJson("/api/admin/storage/predictions/{$record->id}/cleanup")->assertForbidden();
        Storage::assertExists($record->storageDirectory() . '/input/frame.tif');
    }

    public function test_admin_statistics_cover_the_platform_and_are_private(): void
    {
        $this->prediction('completed'); $this->prediction('pending');
        $this->apiAs($this->userToken)->getJson('/api/admin/stats')->assertForbidden();
        $this->apiAs($this->adminToken)->getJson('/api/admin/stats')->assertOk()
            ->assertJsonPath('data.analyses_total', 2)->assertJsonPath('data.users_total', 2)
            ->assertJsonPath('data.analyses_by_status.completed', 1);
    }

    public function test_the_report_lists_only_finished_predictions(): void
    {
        $finished = $this->prediction('completed');
        $this->prediction('pending'); $this->prediction('processing'); $this->prediction('uploaded');
        $this->apiAs($this->adminToken)->getJson('/api/admin/storage')->assertOk()
            ->assertJsonCount(1, 'data.cleanup_candidates')
            ->assertJsonPath('data.cleanup_candidates.0.id', $finished->id)
            ->assertJsonPath('data.cleanup_candidates.0.bytes', strlen('original frame'));
    }

    public function test_cleanup_preserves_history_evidence_and_unrelated_files(): void
    {
        $record = $this->prediction('completed');
        Storage::put('news/published.jpg', 'publication'); Storage::put('.storage-mounted', 'sentinel');
        $this->apiAs($this->adminToken)->postJson("/api/admin/storage/predictions/{$record->id}/cleanup")->assertOk();
        Storage::assertMissing($record->storageDirectory() . '/input/frame.tif');
        Storage::assertExists("prediction-evidence/{$record->user_id}/{$record->job_id}/thumbnail.png");
        Storage::assertExists('news/published.jpg'); Storage::assertExists('.storage-mounted');
        $this->assertNotNull($record->fresh()->files_deleted_at);
        $this->assertDatabaseHas('user_activities', ['activity_type' => 'storage_cleanup', 'user_id' => $this->admin->id]);
        $this->apiAs($this->adminToken)->postJson("/api/admin/storage/predictions/{$record->id}/cleanup")->assertOk()->assertJsonPath('data.freed_bytes', 0);
    }

    public function test_active_and_unstarted_jobs_cannot_be_removed(): void
    {
        foreach (['pending', 'processing', 'uploaded'] as $status) {
            $record = $this->prediction($status);
            $this->apiAs($this->adminToken)->postJson("/api/admin/storage/predictions/{$record->id}/cleanup")->assertStatus(409);
            Storage::assertExists($record->storageDirectory() . '/input/frame.tif');
        }
    }

    public function test_retention_does_not_delete_expired_active_work(): void
    {
        $pending = $this->prediction('pending'); $processing = $this->prediction('processing'); $finished = $this->prediction('completed');
        foreach ([$pending, $processing, $finished] as $record) $record->update(['expires_at' => now()->subHour()]);
        $this->apiAs($this->adminToken)->postJson('/api/admin/storage/cleanup')->assertOk();
        Storage::assertExists($pending->storageDirectory() . '/input/frame.tif');
        Storage::assertExists($processing->storageDirectory() . '/input/frame.tif');
        Storage::assertMissing($finished->storageDirectory() . '/input/frame.tif');
    }

    public function test_missing_mount_and_invalid_directories_are_refused(): void
    {
        $record = $this->prediction('failed');
        config(['storage_guard.require_sentinel' => true, 'storage_guard.sentinel_file' => '.missing']);
        $this->apiAs($this->adminToken)->postJson("/api/admin/storage/predictions/{$record->id}/cleanup")->assertStatus(409);
        config(['storage_guard.require_sentinel' => false]);
        $record->update(['job_id' => '../../news']);
        Storage::put('news/important.jpg', 'keep');
        $this->apiAs($this->adminToken)->postJson("/api/admin/storage/predictions/{$record->id}/cleanup")->assertStatus(409);
        Storage::assertExists('news/important.jpg');
    }
}
