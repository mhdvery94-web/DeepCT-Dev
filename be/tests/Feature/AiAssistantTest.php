<?php

namespace Tests\Feature;

use App\Jobs\GenerateAiReply;
use App\Models\AiMessage;
use App\Models\AiRequest;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use App\Services\AiContext;
use App\Services\QueueHealth;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Queue\TimeoutExceededException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class AiAssistantTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();
        config(['ai.enabled' => true, 'ai.lock_store' => 'file']);
        Http::preventStrayRequests();
        Queue::fake();
        $this->owner = User::factory()->create(['is_active' => true, 'must_change_password' => false]);
        $this->token = $this->owner->createToken('test')->plainTextToken;
    }

    private function conversation(): int
    {
        return $this->apiAs($this->token)->postJson('/api/ai/conversations', [])
            ->assertCreated()->json('data.id');
    }

    private function send(int $id, string $key = 'first', array $extra = [])
    {
        return $this->apiAs($this->token)->postJson("/api/ai/conversations/{$id}/messages", $extra + [
            'content' => 'Apa status interpolasi?', 'idempotency_key' => $key,
        ]);
    }

    private function work(int $id): void
    {
        app()->call([new GenerateAiReply($id), 'handle']);
    }

    public function test_anonymous_and_foreign_owners_cannot_access_ai(): void
    {
        $this->apiAs(null)->getJson('/api/ai/status')->assertUnauthorized();
        $id = $this->conversation();
        $requestId = $this->send($id)->assertAccepted()->json('data.request.id');
        $other = User::factory()->create(['role' => 'admin', 'is_active' => true]);
        $token = $other->createToken('test')->plainTextToken;
        $this->apiAs($token)->getJson("/api/ai/conversations/{$id}")->assertNotFound();
        $this->apiAs($token)->postJson("/api/ai/conversations/{$id}/messages", [
            'content' => 'Other', 'idempotency_key' => 'other',
        ])->assertNotFound();
        $this->apiAs($token)->getJson("/api/ai/requests/{$requestId}")->assertNotFound();
        $this->apiAs($token)->postJson("/api/ai/requests/{$requestId}/cancel")->assertNotFound();
        $this->apiAs($token)->getJson('/api/ai/conversations')->assertJsonCount(0, 'data.conversations');
    }

    public function test_disabled_status_is_honest_and_input_is_validated(): void
    {
        $id = $this->conversation();
        $this->send($id, extra: ['content' => '  '])->assertUnprocessable();
        config(['ai.enabled' => false]);
        $data = $this->apiAs($this->token)->getJson('/api/ai/status')->assertOk()->json('data');
        $this->assertFalse($data['enabled']);
        $this->assertSame(2048, $data['limits']['context_tokens']);
        $this->assertArrayNotHasKey('base_url', $data);
        $this->send($id)->assertStatus(503);
    }

    public function test_idempotency_and_one_active_request_apply_across_conversations(): void
    {
        $id = $this->conversation();
        $first = $this->send($id)->assertAccepted()->json('data');
        $this->send($id)->assertAccepted()->assertJsonPath('data.request.id', $first['request']['id']);
        $this->send($id, extra: ['content' => 'Changed'])->assertConflict();
        $this->send($this->conversation(), 'second')->assertConflict();
        $this->assertSame(1, AiRequest::count());
        $this->assertSame(1, AiMessage::count());
        Queue::assertPushed(GenerateAiReply::class, 1);
        Queue::assertPushed(GenerateAiReply::class, fn ($job) => $job->connection === 'llm' && $job->queue === 'llm');
    }

    public function test_daily_and_global_limits_do_not_persist_rejected_messages(): void
    {
        $id = $this->conversation();
        config(['ai.daily_limit' => 1]);
        $requestId = $this->send($id)->assertAccepted()->json('data.request.id');
        $this->apiAs($this->token)->postJson("/api/ai/requests/{$requestId}/cancel")->assertOk();
        $this->send($id, 'next')->assertStatus(429);
        config(['ai.daily_limit' => 20, 'ai.queue_limit' => 0]);
        $this->send($id, 'next')->assertStatus(429);
        $this->assertSame(1, AiMessage::count());
    }

    public function test_default_daily_limit_is_twenty_admissions_including_cancellations(): void
    {
        $id = $this->conversation();
        foreach (range(1, 20) as $index) {
            $requestId = $this->send($id, "daily-{$index}")->assertAccepted()->json('data.request.id');
            $this->apiAs($this->token)->postJson("/api/ai/requests/{$requestId}/cancel")->assertOk();
        }
        $this->send($id, 'daily-21')->assertStatus(429)->assertJsonPath('error_code', 'daily_limit');
        $this->assertSame(20, AiRequest::count());
        $this->assertSame(20, AiMessage::count());
        // Replays never consume another admission, including at the limit.
        $this->send($id, 'daily-20')->assertAccepted();
    }

    public function test_revoked_accounts_and_disabled_feature_never_call_provider(): void
    {
        foreach (['inactive', 'password', 'disabled'] as $state) {
            $id = $this->conversation();
            $requestId = $this->send($id, $state)->assertAccepted()->json('data.request.id');
            if ($state === 'inactive') {
                $this->owner->update(['is_active' => false]);
            }
            if ($state === 'password') {
                $this->owner->update(['must_change_password' => true]);
            }
            if ($state === 'disabled') {
                config(['ai.enabled' => false]);
            }
            $this->work($requestId);
            $this->assertSame('failed', AiRequest::findOrFail($requestId)->status);
            $this->owner->update(['is_active' => true, 'must_change_password' => false]);
            config(['ai.enabled' => true]);
        }
        Http::assertNothingSent();
    }

    public function test_cancelled_inflight_answer_is_not_published_and_lease_remains_held(): void
    {
        $id = $this->conversation();
        $requestId = $this->send($id)->assertAccepted()->json('data.request.id');
        Http::fake(function () use ($requestId) {
            $this->apiAs($this->token)->postJson("/api/ai/requests/{$requestId}/cancel")
                ->assertOk()->assertJsonPath('data.status', 'cancelled');
            $lock = Cache::store('file')->lock('ai:generation', 330);
            $this->assertFalse($lock->get());

            return Http::response(['done' => true, 'done_reason' => 'stop', 'message' => ['content' => 'Late answer']]);
        });
        $this->work($requestId);
        $this->assertSame('cancelled', AiRequest::findOrFail($requestId)->status);
        $this->assertSame(0, AiMessage::where('role', 'assistant')->count());
        $lock = Cache::store('file')->lock('ai:generation', 330);
        $this->assertTrue($lock->get());
        $lock->release();
    }

    public function test_timeout_and_invalid_output_fail_without_storing_reasoning(): void
    {
        Http::fake(function () use (&$kind) {
            return $kind === 'timeout' ? throw new ConnectionException('secret internal URL') : Http::response([
                'done' => $kind !== 'malformed', 'done_reason' => $kind === 'length' ? 'length' : 'stop',
                'message' => ['content' => in_array($kind, ['length', 'malformed']) ? 'Incomplete' : $kind],
            ]);
        });
        foreach (['<think>private reasoning</think>', '<think>unterminated', '<think',
            '<think>outer<think>inner</think>still private reasoning',
            '<think>outer<think>inner</think></think>answer',
            '<think>first</think><think>second</think>answer',
            '<think>private reasoning</think extra>answer',
            '<thinking>private reasoning</thinking>answer',
            'answer<think>private reasoning</think>',
            'length', 'malformed', 'timeout'] as $kind) {
            $id = $this->conversation();
            $requestId = $this->send($id, hash('sha256', $kind))->assertAccepted()->json('data.request.id');
            $this->work($requestId);
            $response = $this->apiAs($this->token)->getJson("/api/ai/requests/{$requestId}")->assertOk();
            $response->assertJsonPath('data.status', 'failed');
            $response->assertJsonPath('data.error_code', $kind === 'timeout' ? 'provider_timeout' : 'invalid_output');
            $this->assertStringNotContainsString('private reasoning', $response->getContent());
            $this->assertStringNotContainsString('secret internal', $response->getContent());
            if ($kind === 'timeout') {
                $lock = Cache::store('file')->lock('ai:generation', 330);
                try {
                    $this->assertFalse($lock->get(), 'Unknown provider completion must retain its lease.');
                } finally {
                    // This serial test owns the only provider call; remove its
                    // deliberate timeout lease rather than wait 330 seconds.
                    $lock->forceRelease();
                }
            }
        }
        $this->assertSame(0, AiMessage::where('role', 'assistant')->count());
    }

    public function test_conversation_defaults_and_timeout_failure_contract(): void
    {
        $id = $this->apiAs($this->token)->postJson('/api/ai/conversations', [])
            ->assertCreated()->assertJsonPath('data.title', 'Percakapan baru')->json('data.id');
        $requestId = $this->send($id)->assertAccepted()->json('data.request.id');
        $job = new GenerateAiReply($requestId);
        $this->assertSame(300, $job->timeout);
        $this->assertSame(1, $job->tries);
        $this->assertTrue($job->failOnTimeout);
        $this->assertLessThan($job->timeout, config('ai.http_timeout'));
        $job->failed(new TimeoutExceededException);
        $this->apiAs($this->token)->getJson("/api/ai/requests/{$requestId}")
            ->assertOk()->assertJsonPath('data.status', 'failed')->assertJsonPath('data.error_code', 'worker_timeout');
    }

    public function test_history_is_bounded_and_queued_cancellation_never_calls_provider(): void
    {
        $id = $this->conversation();
        foreach (range(1, 12) as $index) {
            AiMessage::create(['ai_conversation_id' => $id, 'role' => $index % 2 ? 'user' : 'assistant',
                'content' => "History {$index} ".str_repeat('x', 1500)]);
        }
        $requestId = $this->send($id)->assertAccepted()->json('data.request.id');
        $request = AiRequest::findOrFail($requestId);
        $prompt = app(AiContext::class)->messages($request, []);
        $history = json_decode(explode('Riwayat/pertanyaan (JSON): ', $prompt[0]['content'])[1], true);
        $this->assertLessThanOrEqual(8, count($history));
        $this->assertLessThanOrEqual(6000, array_sum(array_map(fn ($m) => mb_strlen($m['content']), $history)));
        $this->assertSame('Apa status interpolasi?', end($history)['content']);
        $this->apiAs($this->token)->postJson("/api/ai/requests/{$requestId}/cancel")->assertOk();
        $this->work($requestId);
        Http::assertNothingSent();
        $this->send($id)->assertAccepted()->assertJsonPath('data.request.status', 'cancelled');
        $this->send($id, 'next')->assertAccepted();
    }

    public function test_shared_admission_and_generation_locks_are_enforced(): void
    {
        $id = $this->conversation();
        $admission = Cache::store('file')->lock('ai:admission', 30);
        $this->assertTrue($admission->get());
        try {
            $this->send($id)->assertStatus(503)->assertJsonPath('error_code', 'admission_busy');
            $this->assertSame(0, AiRequest::count());
        } finally {
            $admission->release();
        }
        $requestId = $this->send($id)->assertAccepted()->json('data.request.id');
        $lease = Cache::store('file')->lock('ai:generation', 330);
        $this->assertTrue($lease->get());
        try {
            $this->work($requestId);
            $this->assertSame('generation_busy', AiRequest::findOrFail($requestId)->error_code);
            Http::assertNothingSent();
        } finally {
            $lease->release();
        }
    }

    public function test_real_database_queue_admission_is_atomic_and_bounded(): void
    {
        Queue::fake()->except(GenerateAiReply::class);
        $id = $this->conversation();
        $this->send($id)->assertAccepted();
        $this->assertSame(1, DB::table('jobs')->where('queue', 'llm')->count());
        $payload = json_decode(DB::table('jobs')->where('queue', 'llm')->value('payload'), true);
        $this->assertSame(300, $payload['timeout']);
        $this->assertSame(1, $payload['maxTries']);
        $this->assertTrue($payload['failOnTimeout']);
        $this->assertStringNotContainsString('Apa status', $payload['data']['command']);
        foreach (range(2, 10) as $index) {
            DB::table('jobs')->insert(['queue' => 'llm', 'payload' => '{}', 'attempts' => 0,
                'reserved_at' => null, 'available_at' => time(), 'created_at' => time()]);
        }
        $request = AiRequest::firstOrFail();
        $this->apiAs($this->token)->postJson("/api/ai/requests/{$request->id}/cancel")->assertOk();
        $this->send($id, 'next')->assertStatus(429)->assertJsonPath('error_code', 'queue_full');
        $this->assertSame(1, AiMessage::count());
    }

    public function test_inflight_account_revocation_prevents_publication(): void
    {
        $id = $this->conversation();
        $requestId = $this->send($id)->assertAccepted()->json('data.request.id');
        Http::fake(function () {
            $this->owner->update(['is_active' => false]);

            return Http::response(['done' => true, 'done_reason' => 'stop', 'message' => ['content' => 'Forbidden answer']]);
        });
        $this->work($requestId);
        $this->assertSame('access_revoked', AiRequest::findOrFail($requestId)->error_code);
        $this->assertSame(0, AiMessage::where('role', 'assistant')->count());
    }

    public function test_success_uses_allowlisted_owner_context_and_separate_sources(): void
    {
        $id = $this->conversation();
        $record = AnalysisRecord::create([
            'user_id' => $this->owner->id, 'job_id' => 'ai-context', 'status' => 'pending',
            'file_name' => 'secret-file', 'input_folder' => '/private/path', 'input_files_count' => 2,
            'validation' => ['secret' => 'token-value'],
        ]);
        $requestId = $this->send($id, extra: ['analysis_record_id' => $record->id])->assertAccepted()->json('data.request.id');
        Http::fake(['*' => Http::response([
            'done' => true, 'done_reason' => 'stop', 'message' => ['content' => '<think>hidden</think>Masih menunggu.'],
            'eval_count' => 40, 'prompt_eval_count' => 100, 'total_duration' => 50000000000,
        ])]);
        $this->work($requestId);
        Http::assertSent(function ($request) {
            $payload = $request->data();
            $this->assertSame(2048, $payload['options']['num_ctx']);
            $this->assertSame(768, $payload['options']['num_predict']);
            $this->assertSame(0.6, $payload['options']['temperature']);
            $this->assertSame(2, $payload['options']['num_thread']);
            $this->assertSame('user', $payload['messages'][0]['role']);
            $encoded = json_encode($payload);
            foreach (['secret-file', '/private/path', 'token-value'] as $secret) {
                $this->assertStringNotContainsString($secret, $encoded);
            }

            return true;
        });
        $this->apiAs($this->token)->getJson("/api/ai/requests/{$requestId}")->assertOk()
            ->assertJsonPath('data.status', 'completed')->assertJsonPath('data.assistant_message.content', 'Masih menunggu.')
            ->assertJsonPath('data.sources.0.status', 'pending')->assertJsonPath('data.metrics.eval_count', 40);
        $this->apiAs($this->token)->getJson("/api/ai/conversations/{$id}?per_page=1")->assertOk()
            ->assertJsonCount(1, 'data.messages')->assertJsonPath('data.pagination.total', 2);
    }

    public function test_foreign_analysis_is_rejected_even_for_admin(): void
    {
        $this->owner->update(['role' => 'admin']);
        $foreign = User::factory()->create();
        $record = AnalysisRecord::create(['user_id' => $foreign->id, 'job_id' => 'foreign', 'status' => 'pending']);
        $this->send($this->conversation(), extra: ['analysis_record_id' => $record->id])->assertNotFound();
        $this->assertSame(0, AiRequest::count());
    }

    public function test_worker_rechecks_analysis_ownership_before_provider_call(): void
    {
        $record = AnalysisRecord::create(['user_id' => $this->owner->id, 'job_id' => 'ownership-change', 'status' => 'pending']);
        $requestId = $this->send($this->conversation(), extra: ['analysis_record_id' => $record->id])
            ->assertAccepted()->json('data.request.id');
        $record->update(['user_id' => User::factory()->create()->id]);
        $this->work($requestId);
        $this->assertSame('context_unavailable', AiRequest::findOrFail($requestId)->error_code);
        Http::assertNothingSent();
    }

    public function test_original_analysis_selection_is_public_for_queued_failed_cancelled_and_context_free_requests(): void
    {
        $record = AnalysisRecord::create(['user_id' => $this->owner->id, 'job_id' => 'original-selection', 'status' => 'pending']);
        $conversationId = $this->conversation();
        $requestId = $this->send($conversationId, extra: ['analysis_record_id' => $record->id])
            ->assertAccepted()->assertJsonPath('data.request.analysis_record_id', $record->id)->json('data.request.id');
        Http::fake(['*' => Http::response([], 503)]);
        $this->work($requestId);
        $this->apiAs($this->token)->getJson("/api/ai/requests/{$requestId}")->assertOk()
            ->assertJsonPath('data.status', 'failed')->assertJsonPath('data.analysis_record_id', $record->id)
            ->assertJsonPath('data.sources', []);
        $cancelledId = $this->send($conversationId, 'cancel-original', ['analysis_record_id' => $record->id])
            ->assertAccepted()->json('data.request.id');
        $this->apiAs($this->token)->postJson("/api/ai/requests/{$cancelledId}/cancel")->assertOk()
            ->assertJsonPath('data.status', 'cancelled')->assertJsonPath('data.analysis_record_id', $record->id)
            ->assertJsonPath('data.sources', []);
        $originalId = $record->id;
        $record->delete();
        $this->apiAs($this->token)->getJson("/api/ai/conversations/{$conversationId}")->assertOk()
            ->assertJsonPath('data.request.analysis_record_id', $originalId);
        $this->send($conversationId, 'context-free')->assertAccepted()
            ->assertJsonStructure(['data' => ['request' => ['analysis_record_id']]])
            ->assertJsonPath('data.request.analysis_record_id', null);
    }

    public function test_deleted_original_analysis_fails_before_provider_even_when_foreign_key_is_cleared(): void
    {
        $record = AnalysisRecord::create(['user_id' => $this->owner->id, 'job_id' => 'delete-before-work', 'status' => 'pending']);
        $originalId = $record->id;
        $requestId = $this->send($this->conversation(), extra: ['analysis_record_id' => $originalId])
            ->assertAccepted()->json('data.request.id');
        $record->delete();
        $this->assertNull(AiRequest::findOrFail($requestId)->analysis_record_id);
        Http::fake(['*' => Http::response(['done' => true, 'done_reason' => 'stop', 'message' => ['content' => 'Should never be requested']])]);
        $this->work($requestId);
        $this->apiAs($this->token)->getJson("/api/ai/requests/{$requestId}")->assertOk()
            ->assertJsonPath('data.status', 'failed')->assertJsonPath('data.error_code', 'context_unavailable')
            ->assertJsonPath('data.analysis_record_id', $originalId)->assertJsonPath('data.assistant_message', null);
        Http::assertNothingSent();
    }

    public function test_deleted_original_analysis_during_generation_prevents_publication(): void
    {
        $record = AnalysisRecord::create(['user_id' => $this->owner->id, 'job_id' => 'delete-before-publication', 'status' => 'pending']);
        $originalId = $record->id;
        $requestId = $this->send($this->conversation(), extra: ['analysis_record_id' => $originalId])
            ->assertAccepted()->json('data.request.id');
        Http::fake(function () use ($record) {
            $record->delete();

            return Http::response(['done' => true, 'done_reason' => 'stop', 'message' => ['content' => 'Must not publish']]);
        });
        $this->work($requestId);
        $this->assertSame('context_unavailable', AiRequest::findOrFail($requestId)->error_code);
        $this->assertSame(0, AiMessage::where('role', 'assistant')->count());
        Http::assertSentCount(1);
    }

    public function test_newly_foreign_original_analysis_during_generation_prevents_publication(): void
    {
        $record = AnalysisRecord::create(['user_id' => $this->owner->id, 'job_id' => 'foreign-before-publication', 'status' => 'pending']);
        $other = User::factory()->create();
        $requestId = $this->send($this->conversation(), extra: ['analysis_record_id' => $record->id])
            ->assertAccepted()->json('data.request.id');
        Http::fake(function () use ($record, $other) {
            $record->update(['user_id' => $other->id]);

            return Http::response(['done' => true, 'done_reason' => 'stop', 'message' => ['content' => 'Must not publish']]);
        });
        $this->work($requestId);
        $this->assertSame('context_unavailable', AiRequest::findOrFail($requestId)->error_code);
        $this->assertSame(0, AiMessage::where('role', 'assistant')->count());
        Http::assertSentCount(1);
    }

    public function test_admitted_original_selection_cannot_be_changed(): void
    {
        $requestId = $this->send($this->conversation())->assertAccepted()->json('data.request.id');
        $this->expectException(\LogicException::class);
        $this->expectExceptionMessage('The admitted analysis selection is immutable.');
        AiRequest::findOrFail($requestId)->update(['requested_analysis_record_id' => 123]);
    }

    public function test_expired_analysis_sources_include_safe_model_and_nullable_validation(): void
    {
        $model = Model::create([
            'name' => str_repeat('CT', 100), 'slug' => 'ct-experiment', 'version' => 'v3',
            'file_path' => '/secret/model.bin', 'description' => 'PRIVATE-DESCRIPTION',
            'auth_token' => 'PRIVATE-TOKEN', 'endpoint_url' => 'http://private-worker',
        ]);
        $record = AnalysisRecord::create([
            'user_id' => $this->owner->id, 'model_id' => $model->id, 'job_id' => 'expired-context',
            'status' => 'completed', 'expires_at' => now()->subDay(), 'files_deleted_at' => now(),
            'input_files_count' => 2, 'output_files_count' => 1, 'processing_time_seconds' => 12,
            'frame_provenance' => array_fill(0, 12, ['index' => 4, 'from' => [2, 6], 'generation' => 1,
                'synthetic_parents' => 0, 'frame' => 'PRIVATE-FILENAME']),
            'validation' => ['mae' => 0.25, 'psnr' => null, 'rmse' => 0.5, 'pixels' => 100,
                'reference_min' => 1, 'reference_max' => 3000, 'index' => 4, 'from' => [2, 6],
                'held_out_frame' => 'PRIVATE-FILENAME', 'error' => 'PRIVATE-ERROR'],
        ]);
        $requestId = $this->send($this->conversation(), extra: ['analysis_record_id' => $record->id])
            ->assertAccepted()->json('data.request.id');
        $request = AiRequest::findOrFail($requestId);
        $sources = app(AiContext::class)->sources($request);
        $source = $sources[0];
        $this->assertTrue($source['expired']);
        $this->assertTrue($source['files_deleted']);
        $this->assertSame('v3', $source['model']['version']);
        $this->assertSame($model->id, $source['model']['id']);
        $this->assertLessThanOrEqual(120, mb_strlen($source['model']['name']));
        $this->assertSame(0.25, $source['metrics']['mae']);
        $this->assertArrayHasKey('psnr', $source['metrics']);
        $this->assertNull($source['metrics']['psnr']);
        $this->assertSame(['index' => 4, 'from' => [2, 6]], $source['validation_provenance']);
        $this->assertCount(8, $source['frame_provenance']);
        $this->assertSame(['index' => 4, 'generation' => 1, 'synthetic_parents' => 0, 'from' => [2, 6]], $source['frame_provenance'][0]);
        $encoded = json_encode(app(AiContext::class)->messages($request, $sources));
        foreach (['PRIVATE-', '/secret/', 'private-worker'] as $secret) {
            $this->assertStringNotContainsString($secret, $encoded);
        }
        $this->assertStringContainsString('tidak membaca', $encoded);
    }

    public function test_llm_jobs_do_not_mask_stalled_ct_or_trigger_false_ct_alarm(): void
    {
        $row = ['payload' => '{}', 'attempts' => 0, 'created_at' => time() - 100, 'available_at' => time() - 100];
        DB::table('jobs')->insert($row + ['queue' => 'llm', 'reserved_at' => null]);
        $this->assertSame(0, app(QueueHealth::class)->inspect()['waiting']);
        DB::table('jobs')->insert($row + ['queue' => 'default', 'reserved_at' => null]);
        DB::table('jobs')->insert($row + ['queue' => 'llm', 'reserved_at' => time()]);
        $this->assertTrue(app(QueueHealth::class)->inspect()['stalled']);
    }
}
