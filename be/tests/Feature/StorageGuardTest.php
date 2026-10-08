<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\User;
use App\Services\StorageGuard;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Two failures that were silent until now: a disk with no room, and a disk
 * that is not there.
 *
 * The second is the one worth the file. An unmounted NAS is not an error — it
 * is an ordinary empty directory, and every write into it succeeds. The
 * frames land on the host's own disk, the researcher is told the job worked,
 * and nobody finds the files again.
 */
class StorageGuardTest extends TestCase
{
    use RefreshDatabase;

    private User $user;
    private string $token;
    private Model $model;

    protected function setUp(): void
    {
        parent::setUp();
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

    // ------------------------------------------------------------- mounting

    public function test_the_sentinel_is_not_demanded_unless_it_is_switched_on(): void
    {
        // The default, and it has to stay the default: a single-disk install
        // has nothing to be absent, and demanding a file nobody created would
        // refuse every upload on every existing deployment.
        config(['storage_guard.require_sentinel' => false]);

        $this->assertTrue(app(StorageGuard::class)->isMounted());
    }

    public function test_a_missing_sentinel_means_not_mounted(): void
    {
        config([
            'storage_guard.require_sentinel' => true,
            'storage_guard.sentinel_file' => '.storage-mounted',
        ]);

        $this->assertFalse(app(StorageGuard::class)->isMounted());
    }

    public function test_marking_the_volume_makes_it_mounted(): void
    {
        config([
            'storage_guard.require_sentinel' => true,
            'storage_guard.sentinel_file' => '.storage-mounted',
        ]);

        $guard = app(StorageGuard::class);
        $guard->mark();

        $this->assertTrue($guard->isMounted());
        $this->assertTrue(Storage::exists('.storage-mounted'));
    }

    public function test_an_unmounted_volume_refuses_an_upload_by_name(): void
    {
        config([
            'storage_guard.require_sentinel' => true,
            'storage_guard.sentinel_file' => '.storage-mounted',
        ]);

        $refusal = app(StorageGuard::class)->refusalFor(1024);

        $this->assertNotNull($refusal);
        $this->assertStringContainsString('not mounted', $refusal);
    }

    // ----------------------------------------------------------------- room

    public function test_an_upload_costs_three_times_its_own_size(): void
    {
        // Frames extracted from it, frames generated from those, and the
        // archive built to hand the results back.
        config(['storage_guard.headroom_multiplier' => 3.0]);

        $this->assertSame(300, app(StorageGuard::class)->requiredBytesFor(100));
    }

    public function test_an_upload_that_would_breach_the_floor_is_refused(): void
    {
        config([
            'storage_guard.require_sentinel' => false,
            'storage_guard.headroom_multiplier' => 3.0,
            // Absurdly high on purpose: whatever the test machine has free,
            // this leaves nothing.
            'storage_guard.minimum_free_bytes' => PHP_INT_MAX - 1,
        ]);

        $refusal = app(StorageGuard::class)->refusalFor(1024);

        $this->assertNotNull($refusal);
        $this->assertStringContainsString('Not enough space', $refusal);
    }

    public function test_an_ordinary_upload_is_allowed_through(): void
    {
        config([
            'storage_guard.require_sentinel' => false,
            'storage_guard.minimum_free_bytes' => 1024,
        ]);

        $this->assertNull(app(StorageGuard::class)->refusalFor(1024));
    }

    // ------------------------------------------------- refused at the door

    public function test_a_chunked_upload_is_refused_before_a_byte_travels(): void
    {
        config([
            'storage_guard.require_sentinel' => true,
            'storage_guard.sentinel_file' => '.storage-mounted',
        ]);

        $this->apiAs($this->token)
            ->postJson('/api/predictions/uploads', [
                'purpose' => 'prediction',
                'model_id' => $this->model->id,
                'total_size' => 1024,
                'filename' => 'frames.zip',
            ])
            // 507, not 400: nothing is wrong with the request, and a smaller
            // file would not get a different answer.
            ->assertStatus(507)
            ->assertJsonPath('success', false);
    }

    public function test_a_healthy_volume_accepts_the_upload(): void
    {
        config([
            'storage_guard.require_sentinel' => false,
            'storage_guard.minimum_free_bytes' => 1024,
        ]);

        $this->apiAs($this->token)
            ->postJson('/api/predictions/uploads', [
                'purpose' => 'prediction',
                'model_id' => $this->model->id,
                'total_size' => 1024,
                'filename' => 'frames.zip',
            ])
            ->assertCreated();
    }

    // ------------------------------------------------------------- the report

    public function test_the_report_separates_what_expires_from_what_does_not(): void
    {
        // A volume at 90% mostly holding results that expire within the day is
        // a different situation from one holding datasets nothing will ever
        // reclaim, and a single "used" figure cannot tell them apart.
        Storage::put('predictions/1/abc/output/frame_002.tif', str_repeat('x', 500));
        Storage::put('prediction-evidence/7/frame_002.png', str_repeat('x', 100));

        $report = app(StorageGuard::class)->report();

        $this->assertSame(500, $report['breakdown']['predictions']);
        $this->assertSame(100, $report['breakdown']['evidence']);
        $this->assertTrue($report['mounted']);
    }

    public function test_the_storage_report_is_admin_only(): void
    {
        $this->apiAs($this->token)
            ->getJson('/api/admin/storage')
            ->assertForbidden();
    }

    public function test_an_administrator_can_read_the_storage_report(): void
    {
        User::create([
            'name' => 'Administrator',
            'email' => 'admin@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'is_active' => true,
        ]);

        $this->apiAs($this->tokenFor('admin@brin.go.id', 'password123'))
            ->getJson('/api/admin/storage')
            ->assertOk()
            ->assertJsonStructure([
                'data' => ['mounted', 'free_bytes', 'total_bytes', 'breakdown'],
            ]);
    }
}
