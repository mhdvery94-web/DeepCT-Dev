# Experimental assistant API and operations

For the isolated production CPU candidate, see the [deployment and readiness
guide](../be/deploy/production/README.md). GPU evidence below is historical and
does not establish acceptance of the CPU candidate. Production activation remains
a separate reviewed step.

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
| GET `/ai/analyses/{id}/evidence` | none | `EvaluationReport` for the caller's analysis / 200 |
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
      "metrics": {"mae": null, "rmse": null, "psnr": null, "ssim": null, "pixels": null, "reference_min": null, "reference_max": null},
      "evaluation": {
        "schema_version": 1,
        "evaluation_status": "legacy_unknown",
        "reason_code": null,
        "metrics": {"mae": null, "rmse": null, "psnr": null, "ssim": null, "pixels": null, "reference_min": null, "reference_max": null},
        "metric_status": {"psnr": "unknown", "ssim": "unknown"},
        "method": null,
        "reference": null,
        "model": {"id": 1, "name": "CT model", "slug": "ct-model", "version": "v1"},
        "baseline": {
          "status": "unavailable",
          "reason_code": null,
          "metrics": {"mae": null, "rmse": null, "psnr": null, "ssim": null, "pixels": null, "reference_min": null, "reference_max": null},
          "metric_status": {"psnr": "unknown", "ssim": "unknown"},
          "method": null
        },
        "comparison": {"status": "unavailable", "precision": null, "mae_reduction": null, "rmse_reduction": null, "psnr_gain_db": null, "ssim_gain": null}
      },
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
and processing time may be null. Validation metric keys are
`mae`, `psnr`, `rmse`, `ssim`, `pixels`, `reference_min`, `reference_max`, with numeric or
null values; missing/null data is not replaced with zero. Numeric validation
provenance may contain `index` and a two-integer `from` array. At most eight
frame provenance entries include only `index`, `from`, `generation` and
`synthetic_parents`. No filenames, paths, model descriptions, credential fields
or free-form error bodies enter this metadata. The assistant does not read TIFF
bytes, including when files expire or are removed.

`GET /api/ai/analyses/3/evidence` returns
`{"success":true,"data":<EvaluationReport>}`. The endpoint always checks
ownership, including for admins: a missing or another user's analysis returns
404; a missing bearer token returns 401. It reads sanitized persisted evidence
without generating a new evaluation or calling the model. Its report has the
same schema as an analysis source's `evaluation`; the latter remains the
snapshot captured for that assistant request.

| `EvaluationReport` field | Contract |
| --- | --- |
| `schema_version` | Integer `1`. |
| `evaluation_status` | `completed`, `no_reference`, `evaluation_failed`, or `legacy_unknown` for records without recognized evaluation state. Prediction completion is separate from evaluation availability. |
| `reason_code` | `no_uploaded_midpoint` for `no_reference`, `measurement_failed` for `evaluation_failed`, otherwise null. Historical missingness stays unknown. |
| `metrics` | Object containing `mae`, `rmse`, `psnr`, `ssim`, `pixels`, `reference_min`, `reference_max`; each is a finite allowed number or null. |
| `metric_status` | `psnr`: `available`, `infinite`, `unavailable`, `unknown`; `ssim`: `available`, `image_too_small`, `unavailable`, `unknown`. Infinite PSNR has null numeric PSNR and an explicit `infinite` status; null alone never means infinity or zero. |
| `method` | Null or allowlisted recorded method parameters: raw uint16, range 65535, MAE/RMSE precision 3 decimals, PSNR precision 2 decimals; SSIM uses a 7×7 uniform window, valid centers, sample covariance, K1 0.01 and K2 0.03. Missing parameters are not inferred. Baseline method may include `baseline:linear_midpoint`, `midpoint_rounding:half_up`. |
| `reference` | Null or `{source:"uploaded_midpoint",index:<integer>,from:[<left>,<right>]}` describing the original uploaded midpoint and its symmetric pair. |
| `model` | Null or sanitized historical snapshot: optional `id`, `name`, `slug`, `version`, `model_id`, 64-character lowercase hexadecimal `sha256`, and `provenance:managed_manifest_sha256\|legacy_registry_metadata`. Current registry edits do not reconstruct missing historical versions. |
| `baseline` | Object with `status:completed\|baseline_failed\|unavailable`, `reason_code:baseline_failed\|null`, `metrics`, `metric_status`, `method`. Baseline failure does not erase model metrics. |
| `comparison` | `status:completed\|unavailable`, `precision:recorded_precision\|null`, and nullable `mae_reduction`, `rmse_reduction`, `psnr_gain_db`, `ssim_gain`. Deltas use recorded rounded precision. |

Sources may also contain up to two separate curated documents, including when
no analysis is selected. Their shape is
`{"type":"document","id":"deepct-sop-evaluation","version":"2026-10-16.v1","title":"Evaluasi terhadap midpoint unggahan","text":"<fixed bounded excerpt>"}`.
Titles are bounded to 120 characters and excerpts to 900 characters. Documents
are explanatory SOP citations, separate from measured analysis evidence.

Provider metrics are optional nonnegative integer keys `prompt_eval_count`,
`eval_count`, `total_duration`, `load_duration`, `prompt_eval_duration`,
`eval_duration`. Duration units are Ollama nanoseconds. Metrics dictionaries
serialize as objects, including `{}`. Display source/metric panels separately
from the experimental answer; verify its facts against the source snapshot.
Never treat generated text as verified scientific advice or executable HTML.

Message content allows 1–2000 characters; whitespace-only input is rejected.
The idempotency key allows 1–100 ASCII letters, digits, `.`, `_`, `:`, `-`.
It is scoped to the owner across conversations. For a new admission,
`analysis_record_id` has three distinct meanings:

| Supplied field | Selection |
| --- | --- |
| Omitted | Inherit the latest admitted request's original selection in this conversation; null when there is none or the previous selection was cleared. |
| Explicit `null` | Clear the selected analysis. |
| Explicit positive integer | Switch to that owned analysis. Missing or foreign analyses return 404, including for admins. |

Inherited selections are also rechecked for existence and ownership. Rejected
admissions do not change the conversation's selected context.

For example, send these bodies to `/api/ai/conversations/7/messages` in order,
waiting for each request to become terminal (or cancelling it) before the next:

```json
{"content":"Jelaskan analisis ini","idempotency_key":"select-3","analysis_record_id":3}
```

```json
{"content":"Bagaimana evaluasinya?","idempotency_key":"follow-up"}
```

The second request inherits analysis 3. A later body with
`"analysis_record_id":null` and a new key clears it; a body with
`"analysis_record_id":4` and a new key switches to owned analysis 4.

Repeating a key with the same content, conversation, and supplied analysis
field presence/value returns the original persisted request/message with 202,
including after completion or cancellation. Replay is checked before selecting
current context. Retrying the exact `follow-up` body above still returns its
original selection of 3 after a later clear or switch. Adding
`"analysis_record_id":null` or `"analysis_record_id":3` to that body with the
same key returns 409 `idempotency_conflict`, even if the effective selection
would otherwise match. Changing any of those payload inputs also conflicts.
Keep the key and the original payload after transport errors; do not fill in
an originally omitted field from the current picker. Requests admitted before
the presence-sensitive hash remain replayable only when the supplied selection
matches their original immutable selection; omission/null equivalence is
retained only for original null selections under that older contract.

There is one active request per user,
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
`deepct-assistant-v1`; bounded metadata mode uses `deepct-metadata-v3`.
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

The dedicated production CPU candidate uses `AI_METADATA_MODE=true` with private
loopback Ollama; follow the deployment guide above. For a GPU gateway deployment,
set the matching authenticated fixed-target model gateway's
`DEEPCT_ASSISTANT_METADATA_MODE=true`. The historically tested staging profile
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
owned GPU runtime and CT work under the existing lock in its separately reviewed
model-server checkout. This production source does not roll out that gateway.
Do not clear that marker merely because a health endpoint responds.

## Client validation scope

Next.js and Flutter include the same owner-scoped assistant, retained evidence,
and explicit context selection. The frozen Flutter lockfile matches the existing
CI SDK, **3.44.9**. Run `flutter pub get --enforce-lockfile`, `flutter analyze` and
`flutter test` with that SDK. No new Android package, signing or release settings
are included in this production source promotion. Native APK/store distribution
and physical Android behavior remain unverified and require a separate rollout.
