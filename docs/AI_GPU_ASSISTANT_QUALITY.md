# TUF GPU assistant acceptance

Evidence cutoff: 2026-10-16, Asia/Jakarta (work started 2026-10-15 UTC).
Backend/model-server acceptance source: `18a4d7672e2894991b5e5c9246fb14f30a9ce7c5`.
The subsequent frontend context-picker change does not alter the evaluated provider
or answer renderer. Raw run reports are retained in the cloud runtime's
`gpu-llm/evidence` directory and the staging hosts' owned evaluation directories.
No runtime credential, environment file, cookie, or weight belongs in Git.

## Activation decision

The isolated staging assistant is enabled only in **bounded metadata mode**.
DeepSeek R1 7B classifies the current question; Laravel renders Indonesian answers
from the selected analysis's authorized metadata. This is suitable for an
experimental explanation of status, stored metrics, and file retention. It does
not inspect TIFF pixels, diagnose findings, execute commands, or certify CT quality.

Five real freeform prompt variants still produced factual, language, or refusal
failures. Freeform DeepSeek did **not** pass, and production/default activation
remains off. Moving computation to a GPU improved latency, not factual reliability.

## Actual runtime and integrity

The TUF has an NVIDIA RTX 4060 Laptop GPU with approximately 8 GB VRAM. The
existing CT process (PID 3743 during this evaluation) remained alive, using about
1,402 MiB. Approximately 6,384 MiB was free before assistant generation.

The isolated user service runs official Ollama 0.11.4 and the same pinned
DeepSeek model already present on the Pi:

| Artifact | SHA-256 |
| --- | --- |
| Official Ollama Linux amd64 archive | `a388afb2ccf4e61a3d0de88f0d0600e9e1d67e56bbc9a011ee287f62780bee33` |
| DeepSeek R1 7B raw manifest | `755ced02ce7befdb13b7ca74e1e4d08cddba4986afdb63a480f2c93d3140383f` |
| 4,683,073,184-byte Q4_K_M weight blob | `96c415656d377afbff962f6cdb2394ab092ccbcbaab4b82525bc4ca800fe8a49` |

All five model blobs were size/digest verified. During actual generation,
Ollama reported 5,929,203,712 bytes of model VRAM residency with context 16,384.
Its `12% CPU / 88% GPU` display describes model placement, not 88% GPU utilization.
The tested profile uses output 128 tokens, four CPU threads, one loaded model,
one parallel request, flash attention, q8_0 KV cache, and `keep_alive:0`.
The GPU admission threshold is 5.5 GiB free VRAM; there is no CPU fallback.

## Quality and end-to-end evidence

| Check | Observed result | Meaning |
| --- | --- | --- |
| Topic classifier, 16 prompts with seeds 17 and 43 | 29/32 expected topics; 32/32 valid JSON | Topic selection is imperfect and cannot be an authorization boundary. |
| Classifier duration including load/unload | Median 2.1815 s; range 2.156–2.493 s | Small controlled benchmark, not a latency SLA. |
| Actual Laravel API, dedicated queue, private gateway, GPU, owned renderer | 26/26 cases, split equally across admin and user | Completed factual/safety canary for bounded metadata mode. |
| API end-to-end duration | Median 3.31 s; maximum 3.343 s | Includes queue/polling in this controlled canary. |
| Anonymous status; foreign analysis, request, and conversation | 401; 404 respectively | Auth and ownership preserved for both roles. |
| Same-payload idempotent replay | Same persisted request ID | No duplicate generation admitted. |
| Real cancellation | Cancelled; no late assistant message after four seconds | Cancellation publication boundary held. |
| Production/staging API health during canary | 52 samples, all HTTP 200 | Availability samples, not a load or resilience test. |

The 26 cases cover pending, processing, uploaded, failed, completed, missing and
zero metrics, provided metrics, expired/deleted files, missing context, injected
model names, unsafe requests, overview, and cross-user/secret requests. Metrics
were deliberately distinct between temporary admin and user fixtures. The answer
always used that owner's snapshot; unsupported error causes and scientific
approval were not invented. No raw topic JSON, reasoning, SQL instructions, or
untrusted model-name instructions entered final replies. Temporary accounts,
tokens, chats, and metadata records were removed after the run.

Two canary initialization attempts failed before any generation and were corrected;
they are not included among the 26 passed cases. A separate shortened diagnostic
prompt also selected an irrelevant topic despite successful transport. The
reported classifier rate is therefore distinct from renderer factual correctness.

## CT coexistence

Two existing real scanner TIFF inputs, each 1024 × 1024 uint16, were submitted
through the configured legacy prediction ingress. This checked transport and GPU
coordination, not a new scientific comparison.

* While the CT lease was held, assistant admission returned 503 `generation_busy`.
* CT started during a real assistant generation waited for the same lease,
  succeeded in 2.386 s, and the assistant completed in 2.145 s.
* Both CT runs returned 2,097,408-byte TIFFs with identical SHA-256
  `b4fe9863d788346bfbbd7da49c340929bc46ab567dae3614024901f461195f83`.
* Ollama's model list was empty after generation, the lease was idle, and the
  original CT process remained alive.
* A separate actual public HTTPS request through ngrok returned the same TIFF
  digest in 13.594 s. The private `/assistant/api/chat` path returned 404 through
  that public endpoint. The HTTPS duration includes the tunnel and transfer.

The TUF public ngrok endpoint targets the loopback ingress on port 8003. Legacy
prediction requests are forwarded through the shared lease with a 15-second wait
and 105 MiB request cap; the original loopback worker on port 8000 remains running.
New registry uploads retain their existing limits. Direct notebook/manual GPU
calls that bypass this ingress are not serialized by the application lease.

The separate registry candidate `ginet-tcd-revisi/1.0.0` remains inactive. Its
earlier ten-triplet evaluation lost to linear interpolation on MAE and PSNR in all
ten cases; no researcher-approved scientific thresholds have been supplied.
Assistant acceptance does not approve that model or change its activation gate.

## Deployed staging boundaries and rollback

The Pi keeps Laravel, authentication, the `deepct_staging` database, and the single
dedicated `deepct-staging-llm` worker. TUF owns the private authenticated gateway
and `deepct-ollama-staging` service. The Pi's original production app/database,
the legacy model process, and the Git `main` branch are preserved. The shared
legacy transport on TUF was wrapped for GPU coordination and explicitly tested.

Staging overrides are `AI_ASSISTANT_ENABLED=true`, `AI_METADATA_MODE=true`,
`AI_OLLAMA_GATEWAY=true`, `AI_ASSISTANT_MODEL=deepseek-r1:7b`, context 16,384,
output 128, and four threads. The gateway's matching metadata flag is true.
Source defaults keep both metadata flags and assistant activation false.
One `llm` worker is separate from CT's default queue. Limits remain one active
request per user, ten queue slots, and twenty admissions per user per day.

To stop new admissions, set the staging `AI_ASSISTANT_ENABLED=false`, refresh
Laravel's config cache, and restart only the owned staging API/LLM worker after
handling active work. Existing conversation history remains readable. Do not
purge the CT queue, rotate production keys, or stop another GPU process.
Follow the model-server README's locked recovery procedure if the durable GPU
uncertainty marker is present. An unlocked file or health response is insufficient.

## Remaining limits

* Final answers are predefined explanations, not unrestricted multi-turn reasoning.
  Topic mistakes can still produce an irrelevant explanation; follow-up ambiguity
  is a known limit because only the current question is classified.
* Sources represent the generation snapshot, not continuously refreshed CT state.
* No TIFF interpretation, retrieval-augmented documents, or clinical validation
  was evaluated. No performance/SLA, stress-load, or scientific accuracy claim is made.
* Further model/runtime changes need fresh pinned integrity and quality evidence.
* Production promotion is separate from this staging pilot and must preserve the
  independently closed CT scientific gate.
