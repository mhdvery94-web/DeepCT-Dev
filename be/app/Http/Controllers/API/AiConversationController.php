<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Jobs\GenerateAiReply;
use App\Models\AiConversation;
use App\Models\AiMessage;
use App\Models\AiRequest;
use App\Models\AnalysisRecord;
use App\Services\AiGroundedReply;
use App\Services\AnalysisEvidence;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class AiConversationController extends Controller
{
    public function status()
    {
        return response()->json(['success' => true, 'data' => [
            'enabled' => config('ai.enabled'), 'model' => config('ai.model'),
            'mode' => config('ai.metadata_mode') ? 'metadata' : 'freeform',
            'prompt_version' => (config('ai.metadata_mode') ? AiGroundedReply::PROMPT_VERSION : config('ai.prompt_version')), 'experimental' => true,
            'limits' => [
                'context_tokens' => config('ai.context_tokens'), 'output_tokens' => config('ai.output_tokens'),
                'history_messages' => config('ai.history_messages'), 'history_characters' => config('ai.history_characters'),
                'message_characters' => config('ai.message_characters'), 'queue' => config('ai.queue_limit'),
                'requests_per_day' => config('ai.daily_limit'), 'active_requests_per_user' => 1,
            ],
        ]]);
    }

    public function evidence(Request $request, int $id, AnalysisEvidence $evidence)
    {
        $record = AnalysisRecord::where('user_id', $request->user()->id)->findOrFail($id);

        return response()->json(['success' => true, 'data' => $evidence->fromRecord($record)]);
    }

    private function pagination($page): array
    {
        return ['current_page' => $page->currentPage(), 'last_page' => $page->lastPage(),
            'per_page' => $page->perPage(), 'total' => $page->total()];
    }

    private function pageSize(Request $request): int
    {
        $validated = $request->validate(['per_page' => 'sometimes|integer|min:1|max:100', 'page' => 'sometimes|integer|min:1']);

        return (int) ($validated['per_page'] ?? 20);
    }

    public function index(Request $request)
    {
        $page = AiConversation::where('user_id', $request->user()->id)->latest('updated_at')->latest('id')
            ->paginate($this->pageSize($request));

        return response()->json(['success' => true, 'data' => [
            'conversations' => $page->getCollection()->map->toPublicArray(), 'pagination' => $this->pagination($page),
        ]]);
    }

    public function store(Request $request)
    {
        $input = $request->validate(['title' => 'sometimes|string|max:120']);
        $conversation = AiConversation::create(['user_id' => $request->user()->id] + $input);

        return response()->json(['success' => true, 'data' => $conversation->refresh()->toPublicArray()], 201);
    }

    private function ownedConversation(Request $request, int $id): AiConversation
    {
        return AiConversation::where('user_id', $request->user()->id)->findOrFail($id);
    }

    public function show(Request $request, int $id)
    {
        $conversation = $this->ownedConversation($request, $id);
        $page = $conversation->messages()->latest('id')->paginate($this->pageSize($request));

        return response()->json(['success' => true, 'data' => $conversation->toPublicArray() + [
            // Page 1 contains newest messages; within each page display oldest first.
            'messages' => $page->getCollection()->reverse()->values()->map->toPublicArray(),
            'pagination' => $this->pagination($page),
            'request' => $conversation->requests()->latest('id')->first()?->toPublicArray(),
        ]]);
    }

    private function error(string $code, string $message, int $status)
    {
        return response()->json(['success' => false, 'error_code' => $code, 'message' => $message], $status);
    }

    public function message(Request $request, int $id)
    {
        $conversation = $this->ownedConversation($request, $id);
        if (! config('ai.enabled')) {
            return $this->error('assistant_disabled', 'The experimental assistant is unavailable.', 503);
        }
        $input = $request->validate([
            'content' => 'required|string|max:'.config('ai.message_characters'),
            'idempotency_key' => 'required|string|max:100|regex:/\A[A-Za-z0-9._:-]+\z/',
            'analysis_record_id' => 'nullable|integer|min:1',
        ]);
        // Hash input presence, never the context inherited later at admission.
        $hash = hash('sha256', json_encode(['v2', $id, $input['content'],
            array_key_exists('analysis_record_id', $input), $input['analysis_record_id'] ?? null]));
        $legacyHash = hash('sha256', json_encode([$id, $input['content'], $input['analysis_record_id'] ?? null]));
        try {
            // Global shared lock serializes the queue capacity and daily counts,
            // while transactions + unique keys protect persistent admission.
            return Cache::store(config('ai.lock_store'))->lock('ai:admission', 30)->block(3, function () use ($request, $conversation, $input, $hash, $legacyHash) {
                return DB::transaction(function () use ($request, $conversation, $input, $hash, $legacyHash) {
                    $user = $request->user()->fresh();
                    if (! $user || ! $user->is_active || $user->must_change_password) {
                        return $this->error('access_revoked', 'Account access is unavailable.', 403);
                    }
                    if (! config('ai.enabled')) {
                        return $this->error('assistant_disabled', 'The experimental assistant is unavailable.', 503);
                    }
                    $replay = AiRequest::where('user_id', $user->id)->where('idempotency_key', $input['idempotency_key'])->first();
                    if ($replay) {
                        // Prior releases treated omission and null identically and did
                        // not inherit context. Accept only their original selection.
                        $legacyReplay = hash_equals($replay->payload_hash, $legacyHash)
                            && $replay->requested_analysis_record_id === (isset($input['analysis_record_id']) ? (int) $input['analysis_record_id'] : null);
                        if (! hash_equals($replay->payload_hash, $hash) && ! $legacyReplay) {
                            return $this->error('idempotency_conflict', 'This key was used for another message.', 409);
                        }

                        return $this->accepted($replay);
                    }
                    $selectedId = array_key_exists('analysis_record_id', $input)
                        ? $input['analysis_record_id']
                        : $conversation->requests()->latest('id')->first()?->requested_analysis_record_id;
                    if ($selectedId !== null) {
                        AnalysisRecord::where('user_id', $user->id)->findOrFail($selectedId);
                    }
                    if (AiRequest::where('user_id', $user->id)->whereIn('status', AiRequest::ACTIVE)->exists()) {
                        return $this->error('request_active', 'Wait for or cancel your active request.', 409);
                    }
                    if (AiRequest::where('user_id', $user->id)->where('created_at', '>=', now()->startOfDay())->count() >= config('ai.daily_limit')) {
                        return $this->error('daily_limit', 'The daily assistant limit has been reached.', 429);
                    }
                    // Cancelled/failed queue entries still consume real queue space
                    // until the worker drains their no-op jobs.
                    $jobs = DB::table(config('queue.connections.llm.table'))->where('queue', 'llm')->count();
                    if (max($jobs, AiRequest::whereIn('status', AiRequest::ACTIVE)->count()) >= config('ai.queue_limit')) {
                        return $this->error('queue_full', 'The assistant queue is full. Try again later.', 429);
                    }
                    $message = $conversation->messages()->create(['role' => 'user', 'content' => $input['content']]);
                    $record = AiRequest::create([
                        'user_id' => $user->id, 'ai_conversation_id' => $conversation->id, 'user_message_id' => $message->id,
                        'analysis_record_id' => $selectedId, 'idempotency_key' => $input['idempotency_key'],
                        'requested_analysis_record_id' => $selectedId,
                        'payload_hash' => $hash, 'model' => config('ai.model'), 'prompt_version' => (config('ai.metadata_mode') ? AiGroundedReply::PROMPT_VERSION : config('ai.prompt_version')), 'status' => 'queued',
                    ]);
                    $conversation->touch();
                    // Same database connection and transaction: queue insertion
                    // either commits together with admission or rolls back.
                    GenerateAiReply::dispatch($record->id);

                    return $this->accepted($record);
                });
            });
        } catch (LockTimeoutException) {
            return $this->error('admission_busy', 'The assistant is busy. Retry with the same key.', 503);
        }
    }

    private function accepted(AiRequest $request)
    {
        return response()->json(['success' => true, 'data' => [
            'request' => $request->toPublicArray(),
            'user_message' => AiMessage::findOrFail($request->user_message_id)->toPublicArray(),
        ]], 202);
    }

    public function request(Request $request, int $id)
    {
        $record = AiRequest::where('user_id', $request->user()->id)->findOrFail($id);

        return response()->json(['success' => true, 'data' => $record->toPublicArray()]);
    }

    public function cancel(Request $request, int $id)
    {
        $record = DB::transaction(function () use ($request, $id) {
            $record = AiRequest::where('user_id', $request->user()->id)->whereKey($id)->lockForUpdate()->firstOrFail();
            if (in_array($record->status, AiRequest::ACTIVE, true)) {
                $record->update(['status' => 'cancelled', 'finished_at' => now()]);
            }

            return $record;
        });

        return response()->json(['success' => true, 'data' => $record->toPublicArray()]);
    }
}
