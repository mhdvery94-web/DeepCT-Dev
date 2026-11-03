<?php

namespace App\Jobs;

use App\Models\AiConversation;
use App\Models\AiMessage;
use App\Models\AiRequest;
use App\Models\User;
use App\Services\AiContext;
use App\Services\AiGroundedReply;
use App\Services\AiProviderException;
use App\Services\AssistantProvider;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Queue\TimeoutExceededException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Throwable;

class GenerateAiReply implements ShouldQueue
{
    use Queueable;

    public int $timeout = 300;

    public int $tries = 1;

    public bool $failOnTimeout = true;

    /** Provider failures that retain a safe deterministic metadata answer. */
    private const CLASSIFIER_FALLBACK_CODES = [
        'provider_timeout',
        'provider_rate_limited',
        'provider_unavailable',
    ];

    public function __construct(public int $requestId)
    {
        $this->onConnection('llm')->onQueue('llm');
    }

    private function allowed(AiRequest $request): bool
    {
        $owner = User::find($request->user_id);

        return config('ai.enabled') && $owner?->is_active && ! $owner->must_change_password
            && AiConversation::where('user_id', $request->user_id)->whereKey($request->ai_conversation_id)->exists();
    }

    public function handle(AiContext $context, AssistantProvider $client, AiGroundedReply $grounded): void
    {
        $request = AiRequest::find($this->requestId);
        if (! $request || $request->status !== 'queued') {
            return;
        }
        if (! $this->allowed($request)) {
            $this->markFailed('access_revoked');

            return;
        }
        $lock = Cache::store(config('ai.lock_store'))->lock('ai:generation', config('ai.generation_lease_seconds'));
        if (! $lock->get()) {
            // A duplicate worker cannot overlap a cancelled provider call.
            $this->markFailed('generation_busy');

            return;
        }
        $releaseLease = true;
        try {
            $claimed = AiRequest::whereKey($this->requestId)->where('status', 'queued')
                ->update(['status' => 'processing', 'started_at' => now()]);
            if (! $claimed) {
                return;
            }
            $request->refresh();
            if (! $this->allowed($request)) {
                throw new AiProviderException('access_revoked');
            }
            $sources = $context->sources($request);
            $question = $context->question($request);
            $intent = config('ai.metadata_mode') ? $grounded->classifyIntent($question) : null;
            if ($intent === 'scope') {
                // Secret, cross-user and mutation requests have an exact local
                // refusal. They do not need to reach an external provider.
                $reply = $this->classifierFallback('scope');
            } else {
                try {
                    $reply = $client->generate($request->model, $context->messages($request, $sources));
                } catch (AiProviderException $exception) {
                    if (! config('ai.metadata_mode')
                        || ! in_array($exception->getMessage(), self::CLASSIFIER_FALLBACK_CODES, true)) {
                        throw $exception;
                    }
                    // The provider only chooses a topic. The final prose still
                    // comes from owned backend evidence, so overview is a safe
                    // default for an ambiguous question during provider outage.
                    $reply = $this->classifierFallback($intent ?? 'overview');
                }
            }
            if (config('ai.metadata_mode')) {
                $reply['answer'] = $grounded->render($reply['answer'], $sources, $question);
            }
            DB::transaction(function () use ($reply, $sources) {
                $request = AiRequest::whereKey($this->requestId)->lockForUpdate()->first();
                if (! $request || $request->status !== 'processing') {
                    return;
                }
                if (! $this->allowed($request)) {
                    throw new AiProviderException('access_revoked');
                }
                // Verify scoped analysis again if ownership changed in flight.
                app(AiContext::class)->sources($request);
                $message = AiMessage::create(['ai_conversation_id' => $request->ai_conversation_id,
                    'role' => 'assistant', 'content' => $reply['answer']]);
                $request->update(['status' => 'completed', 'assistant_message_id' => $message->id,
                    'model' => $reply['model'], 'sources' => $sources,
                    'metrics' => $reply['metrics'], 'finished_at' => now()]);
                AiConversation::whereKey($request->ai_conversation_id)->update(['updated_at' => now()]);
            });
        } catch (AiProviderException $e) {
            if ($e->getMessage() === 'provider_timeout') {
                $releaseLease = false;
            }
            $this->markFailed($e->getMessage());
        } catch (Throwable) {
            $this->markFailed('generation_failed');
        } finally {
            // Cancellation never force-releases this lease. A killed worker
            // leaves it until TTL, beyond both the provider and job timeouts.
            if ($releaseLease) {
                $lock->release();
            }
        }
    }

    /** @return array{answer: string, metrics: array{classifier_fallback: int}, model: string} */
    private function classifierFallback(string $topic): array
    {
        return [
            'answer' => json_encode(['topic' => $topic], JSON_THROW_ON_ERROR),
            'metrics' => ['classifier_fallback' => 1],
            'model' => 'deterministic:'.AiGroundedReply::PROMPT_VERSION,
        ];
    }

    private function markFailed(string $code): void
    {
        AiRequest::whereKey($this->requestId)->whereIn('status', AiRequest::ACTIVE)
            ->update(['status' => 'failed', 'error_code' => $code, 'finished_at' => now()]);
    }

    public function failed(?Throwable $exception): void
    {
        $this->markFailed($exception instanceof TimeoutExceededException ? 'worker_timeout' : 'worker_failed');
    }
}
