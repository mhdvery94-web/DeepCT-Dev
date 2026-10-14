<?php

namespace Tests\Feature;

use App\Models\AiRequest;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\ModelUpload;
use App\Models\User;
use App\Services\AiContext;
use App\Services\ModelUploads;
use App\Services\ResultEvidence;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Factory;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

class FinalModelRecoveryTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): array
    {
        $user = User::factory()->create(['role' => 'admin', 'is_active' => true]);

        return [$user, $user->createToken('test')->plainTextToken];
    }

    private function manifest(): array
    {
        return ['schema_version' => 1, 'model_id' => 'fixture', 'version' => '1.0.0', 'name' => 'Fixture', 'description' => '',
            'framework' => 'tensorflow', 'adapter' => 'ginet-tcd-v1', 'weight_file' => 'model.h5', 'sha256' => str_repeat('a', 64), 'size_bytes' => 100,
            'input' => ['width' => 1024, 'height' => 1024, 'dtype' => 'uint16', 'time_scalar' => 0.5]];
    }

    protected function setUp(): void
    {
        parent::setUp();
        config(['model_uploads.internal_url' => 'https://tuf', 'model_uploads.public_url' => 'https://public.tuf',
            'model_uploads.management_token' => 'management', 'model_uploads.inference_token' => 'inference']);
    }

    public function test_lost_create_response_and_failed_attachment_recover_owned_intent(): void
    {
        [$owner,$token] = $this->admin();
        $key = '11111111-1111-4111-8111-111111111111';
        $remote = '22222222-2222-4222-8222-222222222222';
        $manifest = $this->manifest();
        $intent = null;
        $calls = 0;
        Http::fake(function ($request) use (&$intent, &$calls, $owner, $manifest, $remote) {
            $row = ModelUpload::where('user_id', $owner->id)->firstOrFail();
            $this->assertNull($row->tuf_id);
            $this->assertSame($row->intent_id, $request->header('Idempotency-Key')[0]);
            $intent ??= $row->intent_id;
            $this->assertSame($intent, $row->intent_id);
            if (++$calls === 1) {
                throw new ConnectionException('lost committed response');
            }

            return Http::response(['id' => $remote, 'manifest' => $manifest, 'offset' => 0, 'state' => 'uploading', 'published' => false]);
        });
        $body = $manifest + ['creation_key' => $key];
        $this->apiAs($token)->postJson('/api/admin/model-uploads', $body)->assertStatus(503);
        $row = ModelUpload::firstOrFail();
        $this->apiAs($token)->getJson('/api/admin/model-uploads/'.$row->id)->assertOk()->assertJsonPath('data.id', $row->id);
        $this->assertSame($remote, $row->fresh()->tuf_id);
        $row->refresh()->update(['tuf_id' => null, 'state' => 'creating']);
        $this->apiAs($token)->postJson('/api/admin/model-uploads', $body)->assertCreated();
        $this->assertSame(1, ModelUpload::count());
        $this->apiAs($token)->postJson('/api/admin/model-uploads', array_replace($body, ['name' => 'changed']))->assertConflict();
        [, $other] = $this->admin();
        $this->apiAs($other)->getJson('/api/admin/model-uploads/'.$row->id)->assertNotFound();
        Http::swap(new Factory);
        Http::fake(['*' => Http::response([], 409)]);
        $this->apiAs($other)->postJson('/api/admin/model-uploads', $body)->assertConflict();
        $this->assertSame($owner->id, $row->fresh()->user_id);
        $this->assertSame($remote, $row->fresh()->tuf_id);
    }

    public function test_same_target_retry_completes_no_delivery_barrier_and_preserves_admitted_jobs(): void
    {
        [$owner,$token] = $this->admin();
        $model = Model::create(['name' => 'Fixture', 'managed_model_id' => 'fixture', 'version' => '1.0.0', 'weight_sha256' => str_repeat('a', 64),
            'endpoint_url' => 'https://tuf/predict/fixture/1.0.0', 'base_url' => 'https://tuf', 'is_active' => true, 'worker_active' => true, 'status' => 'online']);
        $upload = ModelUpload::create(['user_id' => $owner->id, 'tuf_id' => '22222222-2222-4222-8222-222222222222', 'manifest' => $this->manifest(), 'state' => 'active']);
        Http::fake(fn () => throw new ConnectionException('not delivered'));
        $path = '/api/admin/model-uploads/'.$upload->id;
        $this->apiAs($token)->postJson($path.'/deactivate')->assertStatus(503);
        $transition = $model->fresh()->availability_transition;
        $this->apiAs($token)->postJson($path.'/activate')->assertConflict();
        Http::swap(new Factory);
        $revision = null;
        Http::fake(function ($request) use ($upload, &$revision) {
            if ($request->method() === 'POST') {
                $revision = $request['revision'];

                return Http::response(['id' => $upload->tuf_id, 'manifest' => $upload->manifest, 'state' => 'ready_for_activate', 'published' => true]);
            }

            return Http::response(['models' => [['name' => 'fixture-v1-0-0', 'model_id' => 'fixture', 'version' => '1.0.0', 'sha256' => str_repeat('a', 64), 'endpoint' => '/predict/fixture/1.0.0', 'active' => false]]]);
        });
        $this->apiAs($token)->postJson($path.'/deactivate')->assertOk();
        $this->assertSame($transition['revision'], $revision);
        $this->assertNull($model->fresh()->availability_transition);
        $this->assertFalse($model->fresh()->is_active);
        foreach (['pending', 'processing'] as $status) {
            $record = AnalysisRecord::create(['user_id' => $owner->id, 'model_id' => $model->id, 'job_id' => uniqid(), 'status' => $status, 'input_folder' => 'inputs', 'output_folder' => 'outputs', 'expires_at' => now()->addDay()]);
            Http::fake();
            $this->apiAs($token)->postJson($path.'/activate')->assertConflict();
            Http::assertNothingSent();
            $record->delete();
        }
    }

    public function test_legacy_pending_transition_can_be_completed_after_additive_upgrade(): void
    {
        [$owner,$token] = $this->admin();
        $manifest = $this->manifest();
        $model = Model::create(['name' => 'Fixture', 'managed_model_id' => 'fixture', 'version' => '1.0.0', 'weight_sha256' => str_repeat('a', 64),
            'endpoint_url' => 'https://tuf/predict/fixture/1.0.0', 'base_url' => 'https://tuf', 'is_active' => false, 'worker_active' => true,
            'availability_transition' => ['id' => 'legacy-transition', 'target_active' => false]]);
        $upload = ModelUpload::create(['user_id' => $owner->id, 'tuf_id' => '22222222-2222-4222-8222-222222222222', 'manifest' => $manifest, 'state' => 'active']);
        Http::fake(function ($request) use ($upload) {
            if ($request->method() === 'POST') {
                $this->assertSame(1, $request['revision']);

                return Http::response(['id' => $upload->tuf_id, 'manifest' => $upload->manifest, 'state' => 'ready_for_activate', 'published' => true]);
            }

            return Http::response(['models' => [['name' => 'fixture-v1-0-0', 'model_id' => 'fixture', 'version' => '1.0.0', 'sha256' => str_repeat('a', 64), 'endpoint' => '/predict/fixture/1.0.0', 'active' => false]]]);
        });
        $this->apiAs($token)->postJson('/api/admin/model-uploads/'.$upload->id.'/deactivate')->assertOk();
        $this->assertNull($model->fresh()->availability_transition);
    }

    public function test_retained_cancelled_and_published_uploads_reject_deletion_before_cleanup(): void
    {
        Storage::fake('local');
        [, $admin] = $this->admin();
        foreach (['cancelled', 'ready_for_activate'] as $state) {
            [$owner] = $this->admin();
            $owner->update(['avatar_path' => 'avatars/'.$owner->id.'.png']);
            $upload = ModelUpload::create(['user_id' => $owner->id, 'tuf_id' => Str::uuid(), 'manifest' => $this->manifest(), 'state' => $state]);
            Storage::put($owner->avatar_path, 'avatar');
            Storage::put('predictions/'.$owner->id.'/result.tif', 'result');
            $model = Model::create(['name' => 'model '.$owner->id, 'version' => 'v1', 'endpoint_url' => 'https://legacy/predict']);
            $record = AnalysisRecord::create(['user_id' => $owner->id, 'model_id' => $model->id, 'job_id' => uniqid(), 'status' => 'completed', 'input_folder' => 'input', 'output_folder' => 'output', 'expires_at' => now()->addDay()]);
            $evidence = ResultEvidence::directoryFor($record).'/evidence.json';
            Storage::put($evidence, 'evidence');
            Storage::put('temp/uploads/'.$owner->id.'/chunk', 'chunk');
            $notification = Str::uuid();
            DB::table('notifications')->insert(['id' => $notification, 'type' => 'test', 'notifiable_type' => User::class, 'notifiable_id' => $owner->id, 'data' => '{}', 'created_at' => now(), 'updated_at' => now()]);
            $this->apiAs($admin)->deleteJson('/api/admin/users/'.$owner->id)->assertConflict();
            try {
                $owner->delete();
                $this->fail('Direct deletion must also be guarded');
            } catch (HttpException $e) {
                $this->assertSame(409, $e->getStatusCode());
            }
            $this->assertNotNull($owner->fresh());
            $this->assertNotNull($record->fresh());
            $this->assertNotNull($upload->fresh());
            $this->assertSame(1, $owner->tokens()->count());
            $this->assertSame(1, $owner->notifications()->count());
            Storage::assertExists($evidence);
            Storage::assertExists('temp/uploads/'.$owner->id.'/chunk');
            Storage::assertExists($owner->avatar_path);
            Storage::assertExists('predictions/'.$owner->id.'/result.tif');
        }
    }

    public function test_bounded_owned_pages_and_search_find_old_management_target(): void
    {
        [$owner,$token] = $this->admin();
        [$other] = $this->admin();
        for ($i = 0; $i < 105; $i++) {
            ModelUpload::create(['user_id' => $owner->id, 'tuf_id' => Str::uuid(), 'manifest' => array_replace($this->manifest(), ['model_id' => $i === 0 ? 'old-active' : ($i === 1 ? 'old-inactive' : 'newer-'.$i)]), 'state' => $i === 0 ? 'active' : ($i === 1 ? 'ready_for_activate' : 'cancelled')]);
        }
        ModelUpload::create(['user_id' => $other->id, 'tuf_id' => Str::uuid(), 'manifest' => array_replace($this->manifest(), ['model_id' => 'old-secret']), 'state' => 'active']);
        $this->apiAs($token)->getJson('/api/admin/model-uploads')->assertOk()->assertJsonCount(50, 'data')->assertJsonPath('pagination.last_page', 3);
        $this->apiAs($token)->getJson('/api/admin/model-uploads?page=3')->assertOk()->assertJsonCount(5, 'data')->assertJsonPath('data.4.manifest.model_id', 'old-active');
        $this->apiAs($token)->getJson('/api/admin/model-uploads?search=old-')->assertOk()->assertJsonCount(2, 'data')->assertJsonPath('data.1.manifest.model_id', 'old-active');
        foreach (['old-active' => 'deactivate', 'old-inactive' => 'activate'] as $identity => $action) {
            $upload = ModelUpload::where('user_id', $owner->id)->where('manifest->model_id', $identity)->firstOrFail();
            Model::create(['name' => $identity, 'managed_model_id' => $identity, 'version' => '1.0.0', 'weight_sha256' => str_repeat('a', 64),
                'endpoint_url' => 'https://tuf/predict/'.$identity.'/1.0.0', 'base_url' => 'https://tuf', 'is_active' => $action === 'deactivate', 'worker_active' => $action === 'deactivate']);
            Http::swap(new Factory);
            Http::fake(function ($request) use ($upload, $identity, $action) {
                if ($request->method() === 'POST') {
                    $this->assertStringEndsWith('/'.$upload->tuf_id.'/'.$action, $request->url());

                    return Http::response(['id' => $upload->tuf_id, 'manifest' => $upload->manifest, 'state' => $action === 'activate' ? 'active' : 'ready_for_activate', 'published' => true]);
                }

                return Http::response(['models' => [['name' => $identity.'-v1-0-0', 'model_id' => $identity, 'version' => '1.0.0', 'sha256' => str_repeat('a', 64), 'endpoint' => '/predict/'.$identity.'/1.0.0', 'active' => $action === 'activate']]]);
            });
            $this->apiAs($token)->postJson('/api/admin/model-uploads/'.$upload->id.'/'.$action)->assertOk();
        }

    }

    public function test_retained_recovery_identity_prevents_destructive_migration_rollback(): void
    {
        [$owner] = $this->admin();
        $upload = app(ModelUploads::class)->creationIntent($owner, '11111111-1111-4111-8111-111111111111', $this->manifest());
        $migration = require database_path('migrations/2026_10_14_060000_add_model_upload_recovery.php');
        try {
            $migration->down();
            $this->fail('Retained intents must prevent metadata rollback.');
        } catch (\RuntimeException $e) {
            $this->assertStringContainsString('retained', $e->getMessage());
        }
        $this->assertSame($upload->intent_id, $upload->fresh()->intent_id);
    }

    public function test_uploaded_status_is_preserved_and_grounded(): void
    {
        [$owner] = $this->admin();
        $model = Model::create(['name' => 'Fixture', 'version' => 'v1']);
        $record = AnalysisRecord::create(['user_id' => $owner->id, 'model_id' => $model->id, 'job_id' => uniqid(), 'status' => 'uploaded', 'input_folder' => 'input', 'output_folder' => 'output', 'expires_at' => now()->addDay()]);
        $request = new AiRequest(['user_id' => $owner->id, 'requested_analysis_record_id' => $record->id, 'user_message_id' => 0]);
        $context = app(AiContext::class);
        $sources = $context->sources($request);
        $this->assertSame('uploaded', $sources[0]['status']);
        $this->assertStringContainsString('uploaded', $context->messages($request, $sources)[0]['content']);
        $this->assertStringContainsString('Start', $context->messages($request, $sources)[0]['content']);
    }
}
