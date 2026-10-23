<?php

namespace Tests\Feature;

use App\Jobs\GenerateAiReply;
use App\Models\AiMessage;
use App\Models\AiRequest;
use App\Models\AnalysisRecord;
use App\Models\User;
use App\Services\AiGroundedReply;
use App\Services\AiProviderException;
use App\Services\AssistantProvider;
use App\Services\GeminiClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Factory;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class GeminiAssistantTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'ai.enabled' => true,
            'ai.metadata_mode' => true,
            'ai.provider' => 'gemini',
            'ai.model' => 'gemini-2.5-flash',
            'ai.gemini_model' => 'gemini-2.5-flash',
            'ai.gemini_api_key' => 'test-only-gemini-key',
            'ai.gemini_timeout' => 30,
            'ai.output_tokens' => 128,
            'ai.ollama_model' => 'deepseek-r1:7b',
            'ai.base_url' => 'https://ollama.test',
            'ai.lock_store' => 'file',
            'ai.daily_limit' => 100,
        ]);
        Http::preventStrayRequests();
        Queue::fake();
    }

    private function geminiResponse(string $topic = 'metrics'): array
    {
        return [
            'candidates' => [[
                'content' => ['role' => 'model', 'parts' => [['text' => json_encode(['topic' => $topic])]]],
                'finishReason' => 'STOP',
            ]],
            'usageMetadata' => ['promptTokenCount' => 41, 'candidatesTokenCount' => 7, 'totalTokenCount' => 48],
        ];
    }

    public function test_gemini_uses_fixed_header_authenticated_structured_endpoint(): void
    {
        Http::fake(['https://generativelanguage.googleapis.com/*' => Http::response($this->geminiResponse())]);

        $reply = app(GeminiClient::class)->generate('gemini-2.5-flash', [[
            'role' => 'user', 'content' => 'Klasifikasikan pertanyaan ini.',
        ]]);

        $this->assertSame('{"topic":"metrics"}', $reply['answer']);
        $this->assertSame(['prompt_eval_count' => 41, 'eval_count' => 7], $reply['metrics']);
        Http::assertSent(function ($request) {
            $this->assertSame(
                'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
                $request->url(),
            );
            $this->assertTrue($request->hasHeader('x-goog-api-key', 'test-only-gemini-key'));
            $this->assertStringNotContainsString('test-only-gemini-key', $request->url());
            $this->assertSame('application/json', $request['generationConfig']['responseMimeType']);
            $this->assertSame(AiGroundedReply::SCHEMA, $request['generationConfig']['responseJsonSchema']);
            $this->assertSame(0, $request['generationConfig']['temperature']);
            $this->assertSame([['role' => 'user', 'parts' => [['text' => 'Klasifikasikan pertanyaan ini.']]]], $request['contents']);

            return true;
        });
    }

    public function test_gemini_configuration_and_safety_failures_do_not_fall_back_or_leak_details(): void
    {
        config(['ai.provider' => 'hybrid']);
        foreach ([[403, [], 'provider_configuration'], [200, [
            'candidates' => [['finishReason' => 'SAFETY']],
            'promptFeedback' => ['blockReason' => 'PRIVATE-UPSTREAM-DETAIL'],
        ], 'provider_blocked']] as [$status, $body, $expected]) {
            Http::swap(new Factory);
            Http::preventStrayRequests();
            Http::fake(['https://generativelanguage.googleapis.com/*' => Http::response($body, $status)]);
            try {
                app(AssistantProvider::class)->generate('gemini-2.5-flash', [['role' => 'user', 'content' => 'Question']]);
                $this->fail('Unsafe or misconfigured provider output must not be accepted.');
            } catch (AiProviderException $exception) {
                $this->assertSame($expected, $exception->getMessage());
                $this->assertStringNotContainsString('PRIVATE', $exception->getMessage());
            }
            $this->assertCount(1, Http::recorded());
        }
    }

    public function test_hybrid_falls_back_to_local_model_only_for_transient_or_invalid_output(): void
    {
        config(['ai.provider' => 'hybrid']);
        foreach ([503, 429, 200] as $status) {
            Http::swap(new Factory);
            Http::preventStrayRequests();
            Http::fake(function ($request) use ($status) {
                if (str_contains($request->url(), 'generativelanguage.googleapis.com')) {
                    return $status === 200
                        ? Http::response(['candidates' => [['finishReason' => 'STOP', 'content' => ['parts' => [['text' => 'not-json']]]]]])
                        : Http::response(['error' => ['message' => 'PRIVATE-UPSTREAM-DETAIL']], $status);
                }

                return Http::response(['done' => true, 'done_reason' => 'stop',
                    'message' => ['content' => '{"topic":"status"}'], 'prompt_eval_count' => 9]);
            });

            $reply = app(AssistantProvider::class)->generate('gemini-2.5-flash', [['role' => 'user', 'content' => 'Status?']]);
            $this->assertSame('deepseek-r1:7b', $reply['model']);
            $this->assertSame('{"topic":"status"}', $reply['answer']);
            $this->assertCount(2, Http::recorded());
            Http::assertSent(fn ($request) => $request->url() === 'https://ollama.test/api/chat'
                && $request['model'] === 'deepseek-r1:7b');
        }
    }

    public function test_missing_key_or_freeform_mode_fails_before_any_external_request(): void
    {
        foreach ([['ai.gemini_api_key' => null], ['ai.metadata_mode' => false]] as $override) {
            config($override);
            try {
                app(AssistantProvider::class)->generate('gemini-2.5-flash', [['role' => 'user', 'content' => 'Question']]);
                $this->fail('Gemini must be fail-closed outside the bounded metadata profile.');
            } catch (AiProviderException $exception) {
                $this->assertSame('provider_configuration', $exception->getMessage());
            }
            Http::assertNothingSent();
            config(['ai.gemini_api_key' => 'test-only-gemini-key', 'ai.metadata_mode' => true]);
        }
    }

    public function test_job_sends_only_the_question_and_records_the_actual_gemini_model(): void
    {
        $owner = User::factory()->create(['is_active' => true, 'must_change_password' => false]);
        $token = $owner->createToken('gemini-test')->plainTextToken;
        $record = AnalysisRecord::create([
            'user_id' => $owner->id,
            'job_id' => 'gemini-owned',
            'status' => 'completed',
            'model_snapshot' => ['name' => 'PRIVATE-MODEL', 'version' => 'PRIVATE-VERSION'],
            'validation' => ['mae' => 0.25, 'secret' => 'PRIVATE-METADATA'],
        ]);
        $conversation = $this->apiAs($token)->postJson('/api/ai/conversations')->assertCreated()->json('data.id');
        $question = 'Bagaimana metrik hasil saya?';
        $requestId = $this->apiAs($token)->postJson("/api/ai/conversations/{$conversation}/messages", [
            'content' => $question,
            'idempotency_key' => 'gemini-owned-request',
            'analysis_record_id' => $record->id,
        ])->assertAccepted()->json('data.request.id');
        AiMessage::create(['ai_conversation_id' => $conversation, 'role' => 'assistant', 'content' => 'PRIVATE-HISTORY']);
        Http::fake(['https://generativelanguage.googleapis.com/*' => Http::response($this->geminiResponse())]);

        app()->call([new GenerateAiReply($requestId), 'handle']);

        $request = AiRequest::findOrFail($requestId);
        $this->assertSame('completed', $request->status);
        $this->assertSame('gemini-2.5-flash', $request->model);
        $this->assertEquals(['prompt_eval_count' => 41, 'eval_count' => 7], $request->metrics);
        $answer = AiMessage::findOrFail($request->assistant_message_id)->content;
        $this->assertStringContainsString('MAE: 0.25', $answer);
        $this->assertStringNotContainsString('PRIVATE', $answer);
        Http::assertSent(function ($sent) use ($question) {
            $payload = json_encode($sent->data());
            $this->assertStringContainsString($question, $payload);
            foreach (['PRIVATE-MODEL', 'PRIVATE-VERSION', 'PRIVATE-METADATA', 'PRIVATE-HISTORY', 'mae'] as $private) {
                $this->assertStringNotContainsString($private, $payload);
            }

            return true;
        });
        $this->apiAs($token)->getJson('/api/ai/status')->assertOk()
            ->assertJsonPath('data.provider', 'gemini')
            ->assertJsonPath('data.model', 'gemini-2.5-flash');
    }
}
