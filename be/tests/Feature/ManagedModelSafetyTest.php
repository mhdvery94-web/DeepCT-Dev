<?php

namespace Tests\Feature;

use App\Models\AiRequest;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\ModelUpload;
use App\Models\User;
use App\Services\AiContext;
use App\Services\ModelAdmission;
use App\Services\ModelCatalogSync;
use App\Services\ModelUploads;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ManagedModelSafetyTest extends TestCase
{
    use RefreshDatabase;

    private function model(array $extra = []): Model
    {
        return Model::create($extra + ['name' => 'Original', 'version' => '1.0.0', 'managed_model_id' => 'fixture',
            'weight_sha256' => str_repeat('a', 64), 'slug' => 'fixture-v1-0-0', 'endpoint_url' => 'https://tuf/predict/fixture/1.0.0',
            'is_active' => true, 'worker_active' => true, 'status' => 'online']);
    }

    private function record(User $user, Model $model, string $status): AnalysisRecord
    {
        return AnalysisRecord::create(['user_id' => $user->id, 'model_id' => $model->id, 'job_id' => uniqid(), 'status' => $status,
            'input_folder' => 'inputs', 'output_folder' => 'outputs', 'expires_at' => now()->addDay()]);
    }

    public function test_start_rechecks_availability_then_snapshots_the_selected_version(): void
    {
        Queue::fake();
        Storage::fake('local');
        $user = User::factory()->create(['is_active' => true]);
        $token = $user->createToken('test')->plainTextToken;
        $model = $this->model(['is_active' => false]);
        $record = $this->record($user, $model, 'uploaded');
        $this->apiAs($token)->postJson('/api/predictions/'.$record->id.'/start')->assertUnprocessable();
        $this->assertSame('uploaded', $record->fresh()->status);
        $model->update(['is_active' => true]);
        $this->apiAs($token)->postJson('/api/predictions/'.$record->id.'/start')->assertOk();
        $snapshot = $record->fresh()->model_snapshot;
        $this->assertSame('1.0.0', $snapshot['version']);
        $this->assertSame(str_repeat('a', 64), $snapshot['sha256']);
        $model->update(['name' => 'Edited']);
        $this->model(['version' => '2.0.0', 'slug' => 'fixture-v2-0-0']);
        $request = new AiRequest(['user_id' => $user->id, 'requested_analysis_record_id' => $record->id]);
        $expectedModel = $snapshot;
        $actualModel = app(AiContext::class)->sources($request)[0]['model'];
        ksort($expectedModel);
        ksort($actualModel);
        $this->assertSame($expectedModel, $actualModel);
        $this->assertStringNotContainsString('https', json_encode($snapshot));
    }

    public function test_legacy_toggle_and_delete_refuse_pending_even_with_zero_counter(): void
    {
        $user = User::factory()->create(['is_active' => true, 'role' => 'admin']);
        $token = $user->createToken('test')->plainTextToken;
        $model = $this->model(['managed_model_id' => null, 'weight_sha256' => null, 'current_jobs_count' => 0]);
        $this->record($user, $model, 'pending');
        $this->apiAs($token)->patchJson('/api/admin/models/'.$model->id.'/toggle')->assertConflict();
        $this->apiAs($token)->deleteJson('/api/admin/models/'.$model->id)->assertConflict();
        $this->assertTrue($model->fresh()->is_active);
    }

    public function test_old_record_does_not_reconstruct_historical_version(): void
    {
        $user = User::factory()->create();
        $record = $this->record($user, $this->model(), 'completed');
        $request = new AiRequest(['user_id' => $user->id, 'requested_analysis_record_id' => $record->id]);
        $source = app(AiContext::class)->sources($request)[0]['model'];
        $this->assertSame('historical_model_snapshot_unavailable', $source['provenance']);
        $this->assertArrayNotHasKey('version', $source);
        $this->assertArrayNotHasKey('sha256', $source);
    }

    public function test_catalog_sync_preserves_tuple_rows_and_edited_display_metadata(): void
    {
        $rows = [['name' => 'fixture-v1-0-0', 'display_name' => 'Remote name', 'description' => 'Remote description',
            'model_id' => 'fixture', 'version' => '1.0.0', 'sha256' => str_repeat('a', 64), 'file' => 'model.h5',
            'endpoint' => '/predict/fixture/1.0.0', 'active' => false]];
        Http::fake(function () use (&$rows) {
            return Http::response(['models' => $rows]);
        });
        $sync = app(ModelCatalogSync::class);
        $sync->sync('https://tuf', 'inference', true, true);
        $first = Model::firstOrFail();
        $this->assertFalse($first->is_active);
        $first->update(['name' => 'Admin title', 'description' => 'Admin notes']);
        $rows[] = array_replace($rows[0], ['name' => 'fixture-v2-0-0', 'version' => '2.0.0', 'endpoint' => '/predict/fixture/2.0.0']);
        Http::fake(function () use (&$rows) {
            return Http::response(['models' => $rows]);
        });
        $sync->sync('https://tuf', 'inference', true, true);
        $sync->sync('https://tuf', 'inference', true, true);
        $this->assertSame(2, Model::count());
        $this->assertSame('Admin title', $first->fresh()->name);
        $this->assertSame('Admin notes', $first->fresh()->description);
        $this->assertSame('1.0.0', $first->fresh()->version);
    }

    public function test_catalog_import_retains_legacy_row_when_machine_slug_collides(): void
    {
        $legacy = $this->model(['managed_model_id' => null, 'endpoint_url' => 'https://legacy/predict']);
        $user = User::factory()->create();
        $record = $this->record($user, $legacy, 'completed');
        Http::fake(['*' => Http::response(['models' => [['name' => 'fixture-v1-0-0', 'model_id' => 'fixture',
            'version' => '1.0.0', 'sha256' => str_repeat('a', 64), 'endpoint' => '/predict/fixture/1.0.0', 'active' => false]]])]);
        app(ModelCatalogSync::class)->sync('https://tuf', 'inference', true, true);
        app(ModelCatalogSync::class)->sync('https://tuf', 'inference', true, true);
        $this->assertSame(2, Model::count());
        $this->assertNull($legacy->fresh()->managed_model_id);
        $this->assertSame('https://legacy/predict', $legacy->fresh()->endpoint_url);
        $this->assertSame($legacy->id, $record->fresh()->model_id);
        $this->assertFalse(Model::whereNotNull('managed_model_id')->firstOrFail()->is_active);
    }

    public function test_timeout_keeps_admission_closed_until_late_target_is_confirmed(): void
    {
        config(['model_uploads.internal_url' => 'https://tuf', 'model_uploads.public_url' => 'https://public.tuf/prefix',
            'model_uploads.management_token' => 'management', 'model_uploads.inference_token' => 'inference']);
        $user = User::factory()->create(['role' => 'admin', 'is_active' => true]);
        $token = $user->createToken('test')->plainTextToken;
        $model = $this->model(['base_url' => 'https://tuf']);
        $upload = ModelUpload::create(['user_id' => $user->id, 'tuf_id' => '11111111-1111-4111-8111-111111111111',
            'manifest' => ['model_id' => 'fixture', 'version' => '1.0.0'], 'state' => 'active']);
        $preview = $this->record($user, $model, 'uploaded');
        $level = DB::transactionLevel();
        $row = ['name' => 'fixture-v1-0-0', 'model_id' => 'fixture', 'version' => '1.0.0',
            'sha256' => str_repeat('a', 64), 'endpoint' => '/predict/fixture/1.0.0', 'active' => true];
        Http::fake(function ($request) use ($model, $level, &$row) {
            if ($request->method() === 'GET') {
                return Http::response(['models' => [$row]]);
            }
            $this->assertNotNull($model->fresh()->availability_transition);
            $this->assertFalse($model->fresh()->is_active);
            $this->assertSame($level, DB::transactionLevel(), 'Transition must commit before the remote request.');
            throw new ConnectionException('response lost');
        });
        $this->apiAs($token)->postJson('/api/admin/model-uploads/'.$upload->id.'/deactivate')->assertStatus(503);
        $this->assertNotNull($model->fresh()->availability_transition);
        $this->apiAs($token)->postJson('/api/predictions/'.$preview->id.'/start')->assertUnprocessable();
        $this->apiAs($token)->postJson('/api/admin/model-uploads/'.$upload->id.'/activate')->assertConflict();

        app(ModelUploads::class)->synchronize();
        $this->assertNotNull($model->fresh()->availability_transition, 'An old state does not prove a delayed mutation terminal.');
        $this->assertFalse($model->fresh()->is_active);
        $row['active'] = false;
        app(ModelUploads::class)->synchronize();
        $this->assertNull($model->fresh()->availability_transition);
        $this->assertFalse($model->fresh()->is_active);
        $this->assertSame('Original', $model->fresh()->name);
    }

    public function test_managed_deactivation_refuses_pending_selected_version_before_remote_call(): void
    {
        $user = User::factory()->create(['role' => 'admin', 'is_active' => true]);
        $token = $user->createToken('test')->plainTextToken;
        $model = $this->model();
        $this->record($user, $model, 'pending');
        $upload = ModelUpload::create(['user_id' => $user->id, 'tuf_id' => '11111111-1111-4111-8111-111111111111',
            'manifest' => ['model_id' => 'fixture', 'version' => '1.0.0'], 'state' => 'active']);
        Http::fake();
        $this->apiAs($token)->postJson('/api/admin/model-uploads/'.$upload->id.'/deactivate')->assertConflict();
        Http::assertNothingSent();
        $this->assertTrue($model->fresh()->is_active);
    }

    public function test_stale_catalog_response_cannot_acknowledge_a_new_transition(): void
    {
        $model = $this->model(['base_url' => 'https://tuf']);
        Http::fake(function ($request) use ($model) {
            if (str_ends_with($request->url(), '/models')) {
                $model->update(['is_active' => false, 'availability_transition' => ['id' => 'new-transition', 'target_active' => true]]);
            }

            return Http::response(['models' => [['name' => 'fixture-v1-0-0', 'model_id' => 'fixture', 'version' => '1.0.0',
                'sha256' => str_repeat('a', 64), 'endpoint' => '/predict/fixture/1.0.0', 'active' => true]]]);
        });
        app(ModelCatalogSync::class)->sync('https://tuf', 'inference', true, true);
        $this->assertSame('new-transition', $model->fresh()->availability_transition['id']);
        $this->assertFalse($model->fresh()->is_active);
    }

    public function test_rerun_rechecks_selected_worker_version_and_retains_original_snapshot(): void
    {
        Queue::fake();
        Storage::fake('local');
        $user = User::factory()->create(['is_active' => true]);
        $token = $user->createToken('test')->plainTextToken;
        $first = $this->model();
        $original = $this->record($user, $first, 'completed');
        $original->update(['model_snapshot' => app(ModelAdmission::class)->snapshot($first)]);
        Storage::put('inputs/frame_001.tif', 'fixture');
        $selected = $this->model(['version' => '2.0.0', 'slug' => 'fixture-v2-0-0', 'worker_active' => false]);
        $this->apiAs($token)->postJson('/api/predictions/'.$original->id.'/rerun', ['model_id' => $selected->id])->assertUnprocessable();
        $this->assertSame(1, AnalysisRecord::count());
        $this->assertCount(1, Storage::allFiles(), 'Rejected admission must remove its new copied frames.');
        $selected->update(['worker_active' => true]);
        $this->apiAs($token)->postJson('/api/predictions/'.$original->id.'/rerun', ['model_id' => $selected->id])->assertCreated();
        $rerun = AnalysisRecord::latest('id')->first();
        $this->assertSame('2.0.0', $rerun->model_snapshot['version']);
        $this->assertSame('1.0.0', $original->fresh()->model_snapshot['version']);
        $this->assertSame($selected->id, $rerun->model_id);
    }
}
