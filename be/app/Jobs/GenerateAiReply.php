<?php

namespace App\Jobs;

use App\Models\AiConversation;
use App\Models\AiMessage;
use App\Models\AiRequest;
use App\Models\User;
use App\Services\AiContext;
use App\Services\AiGroundedReply;
use App\Services\AiProviderException;
use App\Services\OllamaClient;
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

    public function handle(AiContext $context, OllamaClient $client): void
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
            $reply = $client->generate($request->model, $context->messages($request, $sources));
            if (config('ai.metadata_mode')) {
                $reply['answer'] = app(AiGroundedReply::class)->render($reply['answer'], $sources);
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
                    'sources' => $sources, 'metrics' => $reply['metrics'], 'finished_at' => now()]);
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
