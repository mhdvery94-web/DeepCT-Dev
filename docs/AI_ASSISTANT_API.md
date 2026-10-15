# Experimental assistant API and operations

The assistant is disabled by default. The earlier freeform production gate failed:
the real Pi `deepseek-r1:1.5b` benchmarks took roughly 51–60 seconds, and both
short Indonesian pending-status answers were incorrect or vague. Those results
do not establish acceptable answer quality. DeepSeek R1 7B on the TUF GPU also
failed freeform factual-quality checks. Neither result authorizes freeform use.
An independently evaluated, bounded metadata mode is enabled in isolated staging:
DeepSeek selects a topic, and Laravel renders the answer from authorized metadata.
See [GPU quality evidence and operations](AI_GPU_ASSISTANT_QUALITY.md). Fresh
environments and production remain disabled; automated unit suites use fakes,
while the separately recorded acceptance tests used the actual TUF GPU.

All routes below use the `/api` prefix and require a Sanctum bearer token, an
active account and completion of any required password change. Admins have the
same ownership boundary as other users. Foreign conversations, requests and
analysis selections return 404. Successful responses use `{success:true,data:…}`.

| Method/path | Input | `data` / HTTP status |
| --- | --- | --- |
| GET `/ai/status` | none | `enabled`, `model`, `mode:freeform\|metadata`, `prompt_version`, `experimental:true`, `limits` / 200 |
| GET `/ai/conversations` | optional `page`, `per_page` | `conversations:Conversation[]`, `pagination` / 200 |
| POST `/ai/conversations` | optional `title` (1–120 characters) | `Conversation` / 201 |
| GET `/ai/conversations/{id}` | optional `page`, `per_page` | `Conversation` plus `messages:Message[]`, `pagination`, `request:AiRequest|null` / 200 |
| POST `/ai/conversations/{id}/messages` | `content`, `idempotency_key`, optional `analysis_record_id` | `request:AiRequest`, `user_message:Message` / 202 |
| GET `/ai/requests/{id}` | none | `AiRequest` / 200 |
| POST `/ai/requests/{id}/cancel` | none | `AiRequest` / 200 |

`Conversation` contains integer `id`, string `title`, and ISO-8601 `created_at`
and `updated_at`. The default title is `Percakapan baru`.
`Message` contains integer `id`, `role:user|assistant`, string `content` and
ISO-8601 `created_at`. `pagination` contains integer `current_page`, `last_page`,
`per_page`, `total`. Page size defaults to 20, allows 1–100, and pages start at 1.
Conversation listings are newest-updated first. Message page 1 contains the
newest messages; messages within each page are returned oldest first. Detail's
`request` is that conversation's latest request, even if terminal.

```json
{
  "success": true,
  "data": {
    "id": 42,
    "conversation_id": 7,
    "user_message_id": 100,
    "analysis_record_id": 3,
    "status": "completed",
    "model": "deepseek-r1:1.5b",
    "prompt_version": "deepct-assistant-v1",
    "error_code": null,
    "experimental": true,
    "assistant_message": {
      "id": 101,
      "role": "assistant",
      "content": "Analisis masih menunggu pemrosesan.",
      "created_at": "2026-10-10T12:01:00+00:00"
    },
    "sources": [{
      "type": "analysis_record",
      "id": 3,
      "status": "pending",
      "input_files_count": 2,
      "output_files_count": 0,
      "processing_time_seconds": null,
      "expired": false,
      "files_deleted": false,
      "model": {"id": 1, "name": "CT model", "slug": "ct-model", "version": "v1"},
      "metrics": {},
      "validation_provenance": {},
      "frame_provenance": []
    }],
    "metrics": {"prompt_eval_count": 100, "eval_count": 40, "total_duration": 50000000000},
    "created_at": "2026-10-10T12:00:00+00:00",
    "started_at": "2026-10-10T12:00:10+00:00",
    "finished_at": "2026-10-10T12:01:00+00:00"
  }
}
```

The example demonstrates the shape, not an observed model answer. Request
states are `queued`, `processing`, `completed`, `failed`, `cancelled`.
`analysis_record_id` is the original authorized prediction selection (integer or
null), independent of generated sources and present even on queued, failed or
cancelled requests. Regeneration uses that original ID with a new idempotency
key; a null original stays context-free even if the composer selects another
prediction. The server retains this immutable selection after prediction
deletion and revalidates its existence and ownership before generation and
publication. Missing or newly foreign context fails as `context_unavailable`;
it never silently becomes a context-free question. The additive migration only
backfills surviving foreign-key selections. Older selections already erased
before that migration remain unknown/null, without inference from snapshots.
`assistant_message` is null until completed; `sources` is empty and provider
`metrics` is null until completed. `started_at` and `finished_at` are nullable.
`sources` is trusted, allowlisted server metadata captured for generation;
it is a snapshot, not a live prediction poll. The CT model field is nullable,
with names/slugs bounded to 120 characters and versions to 64. Source counts
and processing time may be null. Validation metric keys are optional
`mae`, `psnr`, `rmse`, `ssim`, `pixels`, `reference_min`, `reference_max`, with numeric or
null values; missing/null data is not replaced with zero. Numeric validation
provenance may contain `index` and a two-integer `from` array. At most eight
frame provenance entries include only `index`, `from`, `generation` and
`synthetic_parents`. No filenames, paths, model descriptions, credential fields
or free-form error bodies enter this metadata. The assistant does not read TIFF
bytes, including when files expire or are removed.

Provider metrics are optional nonnegative integer keys `prompt_eval_count`,
`eval_count`, `total_duration`, `load_duration`, `prompt_eval_duration`,
`eval_duration`. Duration units are Ollama nanoseconds. Metrics dictionaries
serialize as objects, including `{}`. Display source/metric panels separately
from the experimental answer; verify its facts against the source snapshot.
Never treat generated text as verified scientific advice or executable HTML.

Message content allows 1–2000 characters; whitespace-only input is rejected.
The idempotency key allows 1–100 ASCII letters, digits, `.`, `_`, `:`, `-`.
It is scoped to the owner across conversations. Repeating the same key with
the same normalized content, conversation and analysis selection returns the
original persisted request/message with 202, including after completion or
cancellation. Changing the payload returns 409. Keep the key after transport
errors and retry using the same payload. There is one active request per user,
10 total queue slots and 20 admissions per user per application day (UTC by
default). Replays do not consume quota; cancelled/failed admissions do. Queued
no-op jobs from cancellation still occupy queue space until a worker drains them.
Only message admission is disabled by the feature flag; existing history,
configuration, conversation creation and cancellation remain available.

Admission errors have `{success:false,error_code,message}`: 503
`assistant_disabled` or `admission_busy`; 409 `idempotency_conflict` or
`request_active`; 429 `daily_limit` or `queue_full`; 403 `access_revoked`.
Existing middleware/auth errors retain their platform message envelope;
validation returns Laravel 422 `{message,errors}` and missing resources return
404. Failed polls retain HTTP 200 and expose only a safe `error_code`:
`access_revoked`, `context_unavailable`, `generation_busy`, `provider_timeout`,
`provider_unavailable`, `invalid_output`, `generation_failed`, `worker_timeout`,
or `worker_failed`. Terminal cancellation is idempotent: completed/failed rows
remain terminal and are returned unchanged.

## Operations prerequisites

Before any separately authorized activation, migrate the three AI tables and
configure `AI_OLLAMA_BASE_URL`, optional `AI_OLLAMA_TOKEN`, and backend-only
`AI_ASSISTANT_MODEL` (default `deepseek-r1:1.5b`). The freeform prompt version is
`deepct-assistant-v1`; bounded metadata mode uses `deepct-metadata-v2`.
Keep `AI_ASSISTANT_ENABLED=false` until the selected mode's quality gate
passes. Client input cannot override the provider URL, credentials or model.
Apply normal Laravel configuration refresh/restart practices for config changes.

API and worker must use the same atomic shared `AI_LOCK_STORE` (default `file`)
and, for file locks, the same cache directory. Do not use process-local/array
locks. The `llm` queue must use the same application database/connection as
admission so request/message/job inserts share a transaction. Use exactly one
dedicated worker, separately from CT's `database/default` worker:

```sh
php artisan queue:work llm --queue=llm --timeout=300 --tries=1
```

Ollama must be configured with `OLLAMA_NUM_PARALLEL=1` and the approved model.
The default freeform request sets `num_thread=2`, temperature 0.6, `num_ctx=2048` and
`num_predict=768` (reasoning included). R1 instructions are in a user prompt,
with at most eight historical messages and 6000 history characters including
the current question. Backend-only `AI_CONTEXT_TOKENS`, `AI_OUTPUT_TOKENS`, and
`AI_THREADS` select a deployed profile; prompt contents are also bounded to
12,000 UTF-8 bytes and the context/output budget, preserving the current question.
A non-streaming request has a 260-second HTTP timeout;
the job has a 300-second timeout, one try and timeout failure enabled; its queue
lease is 360 seconds. The single generation lock has a 330-second lease.

Cancellation releases the user request immediately and prevents a late answer
from being published; it does not immediately abort Ollama. The generation
lease stays held until the call returns. HTTP timeouts and killed workers leave
the lease until expiry. While held, another generation fails safely with
`generation_busy`. An expired application lease cannot prove an abandoned
Ollama computation stopped; exactly one worker and provider parallelism of one
are required. No code here changes the live Ollama service. Provider errors,
reasoning-only/malformed/unterminated thinking and length-truncated replies
become safe failed states; raw provider content and reasoning are not logged
or saved. Restarting/deactivating accounts or requiring a password change is
rechecked before provider execution and before answer publication.

CT queue health counts only `default` jobs, so an LLM reservation cannot mask
a stalled CT queue or trigger a false CT stall alarm. Managed training remains
retired; the assistant cannot execute tools, run jobs, inspect raw files or
retrieve other accounts' data.

## Bounded metadata profile

Set `AI_METADATA_MODE=true` only with the matching authenticated fixed-target
model gateway's `DEEPCT_ASSISTANT_METADATA_MODE=true`. The tested staging profile
uses `deepseek-r1:7b`, context 16,384, output 128, four CPU threads, and
`AI_OLLAMA_GATEWAY=true`. `AI_OLLAMA_BASE_URL` is the private model gateway base
ending in `/assistant`; its bearer credential is backend-only. Never publish
Ollama or put this bearer in either frontend.

The request uses `think:false` and a strict topic schema: `status`, `metrics`,
`files`, `overview`, or `scope`. Only the current question is sent to the model;
analysis metadata, model names, filenames, previous messages, and TIFF bytes are
not sent in this mode. Laravel validates the returned topic object, then renders
Indonesian templates from the same authorized source snapshot exposed by the API.
No provider prose or reasoning becomes the answer. Missing metrics remain
unknown, zero remains zero, and completed processing never implies scientific
approval. The classifier may select an irrelevant topic; it cannot select another
owner's data, run actions, or invent template values. With no selection the reply
asks the user to choose an owned analysis.

Next.js and Flutter expose `Pilih analisis` using the existing owner-scoped
`GET /predictions?page=N&per_page=20` list, for admins and users alike. Archived
analyses remain selectable because their retained metadata can still be explained.
The picker does not grant access to global admin analysis records. A later picker
change applies to new messages; retry and regeneration retain their original
admitted analysis selection.

The model gateway coordinates a shared GPU file lease with CT work and verifies
model unloading before releasing successful assistant generations. It preserves
an uncertainty marker after ambiguous failures. Recovery requires checking the
owned runtime and CT work under the existing lock; see the
[model-server recovery procedure](../deepct-model-server/README.md#private-gpu-assistant-gateway).
Do not clear that marker merely because a health endpoint responds.
