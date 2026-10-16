# Prediction evidence implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver measured prediction evidence and a grounded staging assistant, with an actual local-model comparison and honest release gates.

**Architecture:** Laravel owns a backward-compatible evaluation report and owner-scoped context. Curated, versioned SOP retrieval augments exact server-rendered answers. Next.js and Flutter expose the same evidence; a separate GPU benchmark assesses freeform without enabling it.

**Tech Stack:** Laravel/PHP, MySQL tests, Python/FastAPI/Ollama on TUF, Next.js/TypeScript, Flutter/Dart, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-16-prediction-evidence-design.md`

## Global Constraints

- Existing develop checkout; no worktree, no production activation, no new external API dependency.
- Only original uploaded midpoint frames are reference truth; raw uint16, range 65535, no independent normalization.
- SSIM 7×7 uniform, sample covariance, K1=0.01, K2=0.03, cropped valid centers; small frames declare unavailable.
- Keep flat validation metric keys; add versioned structured state and baseline. No raw exceptions or file paths in assistant evidence.
- Shared GPU lease and verified unload discipline remain mandatory; do not stop legacy CT or unrelated jobs.
- Every task uses meaningful RED/GREEN tests, self-review, focused validation, and a task-scoped review. Root owns commits/index and remote operations; implementers do not commit or spawn agents.
- Production, scientist CT acceptance, and physical Android QA remain separate gates; unexecuted checks cannot be passed.

## Review Focus

1. Zero-MSE infinity versus rounded zero and missing PSNR must remain distinct (Task 1 numerical test; Task 2/3 presentation).
2. A failed baseline must not discard successful model metrics or generated output (Task 1 pipeline test).
3. An idempotent retry after context switching must replay its original request, and explicit null must not inherit (Task 2 admission tests).
4. Unknown legacy or malicious nested report fields must not invent a cause, leak a path, or break clients (Task 2 sanitizer, Task 3 render tests).
5. A model timeout or interrupted benchmark must preserve GPU poison until verified idle, and never auto-enable freeform (Task 4 harness tests).

---

### Task 1: Structured evaluation, SSIM, linear baseline

**Files:** Modify `be/app/Services/FrameMetrics.php`, `be/app/Jobs/ProcessDeepLearningImage.php`, `be/tests/Unit/FrameMetricsTest.php`, `be/tests/Feature/PredictionPipelineTest.php`; create focused `be/app/Services/AnalysisEvidence.php` and tests as needed.

**Interfaces:** Existing `FrameMetrics::compare(string $referenceTiff, string $candidateTiff): array` retains numeric keys and adds method/status fields; add `compareMidpoint(string $referenceTiff, string $leftTiff, string $rightTiff): array` for linear baseline. Produce `AnalysisEvidence::fromRecord(AnalysisRecord $record): array`, a sanitized evaluation-only object with `schema_version`, `evaluation_status`, `reason_code`, `metrics`, `metric_status`, `method`, `reference`, `model`, `baseline`, `comparison`. Flat persisted validation adds `schema_version=1`, `evaluation_status`, `reason_code`, `psnr_status`, `ssim_status`, `method`, `baseline`, `comparison`; numeric `index/from` remain provenance. Legacy/null yields `legacy_unknown`, no inferred cause. Task 2 consumes this object.

- [ ] Add independent numerical SSIM fixtures (obtain golden constants from scikit-image, store input formula and expected values), exact identical, small-image, mismatched size, zero-MSE versus tiny rounded error, midpoint rounding tests.
- [ ] Run focused PHPUnit tests and save actual expected-failure evidence before implementation.
- [ ] Implement bounded-memory moments/window evaluation and midpoint baseline; method explicitly records raw uint16 range/window/covariance parameters. Do not allocate full-frame PHP arrays.
- [ ] Update held-out evaluation with `completed`, `no_reference/no_uploaded_midpoint`, `evaluation_failed/measurement_failed`, model snapshot and reference provenance. Model output remains completed if evaluation fails. Baseline failures expose `baseline_failed` separately; comparisons use unrounded values when feasible or explicitly labeled recorded precision.
- [ ] Add pipeline assertions for no valid midpoint, valid held-out pair, measurement failure, and baseline-only failure preserving output/model metrics; add sanitizer tests for unknown legacy, non-finite values, nested secrets/paths, forged codes.
- [ ] Run `php artisan test --compact --filter='FrameMetricsTest|PredictionPipelineTest|AnalysisEvidenceTest'` from `be`; report tests, memory/time observation for a 2048² comparison, diff/self-review. Root commits.

### Task 2: Owner context, follow-ups, curated SOP retrieval

**Files:** Modify `be/app/Services/AiContext.php`, `be/app/Services/AiGroundedReply.php`, `be/app/Jobs/GenerateAiReply.php`, `be/app/Http/Controllers/API/AiConversationController.php`, `be/routes/api.php`, relevant `be/tests/Feature/Ai*`/`be/tests/Unit/Ai*`; create `be/app/Services/AiKnowledge.php`, versioned `be/resources/ai/sop.json`.

**Interfaces:** Consume `AnalysisEvidence::fromRecord`. Add `GET /api/ai/analyses/{id}/evidence` authenticated and scoped to user even for admin. `AiContext::sources` includes existing analysis evidence plus sanitized `evaluation`, then separate `type=document` sources (`id`, `version`, `title`, `text`) from controlled SOP retrieval. Existing `metrics` and numeric provenance stay compatible. `AiKnowledge::retrieve(string $question): array` returns at most two fixed, bounded document excerpts. Follow-up omitted ID inherits previous request selection in same conversation; explicit null clears. Replay hash describes user-supplied input presence/value, not later inherited selection.

- [ ] Write failing tests for evidence API 200/401/404 (other-user/admin), context omission/explicit null/switch, replay after switch and previously cleared context, active concurrency, legacy missingness, and safe replay compatibility for requests admitted with the prior payload-hash contract.
- [ ] Implement owner-scoped endpoint and single shared report sanitizer; no duplicated envelope parser.
- [ ] Add curated Indonesian SOP entries (evaluation, metrics, lifecycle, retention, model approval), deterministic keyword/topic retrieval, stable IDs/versions; no runtime arbitrary file fetch. Test unrelated/secret questions, no selected analysis, strict size bounds.
- [ ] Extend bounded metadata answers with recorded availability/reasons, infinite PSNR, baseline comparison, method/source labels, and relevant SOP citation. No unsupported scientific conclusions. Do not execute arbitrary instructions in model names/doc snippets. Preserve classifier schema for deployed fixed-target gateway. Bad classifier JSON selects deterministic safe overview; transport timeout stays a provider failure with lease rules intact.
- [ ] Update prompt version for richer metadata contract consistently in status/admission. Test snapshots and rechecked ownership, zero versus missing values, raw error exclusion, inherited follow-up, document-only answer.
- [ ] Run focused AI/Evidence tests; report RED/GREEN evidence and self-review. Root commits.

### Task 3: Shared report presentation in Next.js and Flutter

**Files:** Modify `fe_web/src/lib/assistant.ts`, `fe_web/src/components/assistant-evidence.tsx`, `fe_web/src/components/research-assistant.tsx`, corresponding Next tests; `fe/lib/widgets/assistant_evidence.dart`, `fe/lib/screens/assistant/research_assistant_screen.dart`, related model/service files and tests as required.

**Interfaces:** Consume Task 2 source types and evaluation report. Preserve the analysis picker and existing role/account flow. Present source snapshots as snapshots, documents as documents; both clients preserve omitted/inherited versus explicit clear behavior.

- [ ] Add failing render/parser tests for completed evaluation, no reference, failed evaluation, legacy unknown, infinite PSNR, small-image SSIM, baseline regression, unknown malformed fields, and SOP citations without analysis.
- [ ] Implement compact accessible BRIN-themed evidence UI with clear labels and model/reference/method/baseline details; null is never displayed as zero or infinity unless explicit status says infinite. No new animation/layout overhaul.
- [ ] Add context inheritance/clear/switch client tests if payload semantics change; keep past-source snapshots immutable on picker changes and no display of arbitrary raw JSON/errors.
- [ ] Run Next unit/lint/typecheck and focused Flutter tests/analyze; record exact results and self-review. Root commits.

### Task 4: Reproducible freeform benchmark and isolated staging APK

**Files:** Create `scripts/evaluate-assistant.py`, `scripts/assistant-quality-cases.json`, focused Python tests following existing CPU test conventions; create `.github/workflows/staging-android.yml`; modify `docs/AI_ASSISTANT.md` or existing equivalent readiness documentation.

**Interfaces:** Benchmark consumes 40 synthetic cases with stable ID/question/sources/history/expected facts, local Ollama URL fixed to loopback 11435, explicit allowed model selection `deepseek-r1:7b` or `qwen2.5:7b-instruct-q4_K_M`. Use the same non-thinking generation profile for both models: `think=false`, context16384, output1024, temperature0.2, seed17, threads4, keep_alive0; report that R1 is evaluated in this constrained deployment profile, not its full reasoning capability. Runs on TUF with existing gateway app import and `GPULease` path given operator-side, no token/URL from frontend. Reports retain final content, timings, rule-check results, model/runtime identity, and explicit `manual_review_required=true`, `activation=false`. No reasoning logs. Artifact download/verification and remote installation handled by root.

- [ ] Write failing harness tests for bad/incomplete answers, finite/infinite/missing metric checks, prompt byte budget, no reasoning export, timeout uncertainty, unload/verified idle, malformed corpus, and report recovery without automatic activation.
- [ ] Implement sequential benchmark respecting shared GPU lock, free-VRAM admission, poison-before-dispatch and successful verified-unload-only clear; on ambiguity fail closed. Rule checks must report scope and limitations, not pretend semantic approval. Checkpoint after every case.
- [ ] Supply 40 distinct, representative cases covering spec section 5 including follow-ups, owner-bound data, curated references and baseline regressions; synthetic data only. Do not copy all provider output to logs.
- [ ] Add a staging APK build workflow with `workflow_dispatch` restricted to develop/staging plus `push` on branch staging limited to this workflow file path (initial build works before the new workflow exists on main), read-only permissions, frozen Flutter 3.44.9, staging/develop URL variable as appropriate, dependent tests/preflight, distinct Android application ID and visible staging name, no release publish/production backend/Drive. Use supported Gradle property or minimal Android flavor changes if needed; document signing/test limitations, source SHA/API in artifact metadata.
- [ ] Run harness unit tests and workflow static/actual dry checks where possible; root later triggers workflow, downloads and checks APK, runs actual model comparison and reviews all answers.
- [ ] Report evidence/self-review; root commits.

### Task 5: Actual acceptance, runtime deployment, delivery (root operations)

- [ ] Verify official candidate manifest/blob checksums and runtime capability; install candidate alongside DeepSeek without replacement. Run actual 40-case baseline/candidate sequential benchmark under GPU lease and manually review final answers. Capture failures honestly; keep bounded metadata staging unless all gates pass.
- [ ] Run final integrated tests appropriate to changed code once; obtain broad whole-branch review and one scoped fix wave if required.
- [ ] Back up and deploy reviewed staging PHP/UI only; preserve production state/secrets and GPU runtime. Execute actual new evaluated interpolation/evidence endpoint when valid input fixtures exist, plus live queue/API canary and browser role flows for both clients. Clean only owned fixtures afterward.
- [ ] Push authorized develop/staging fast forwards, inspect CI/Vercel outcomes, build/download isolated staging APK. Check for an available authorized Android device; if absent record physical QA unverified.
- [ ] Synchronize Windows repository preserving current changes/stash. Archive report, source bundle, final answers/gates, reviews and helper instructions with checksums; verified laptop copy. Do not retry known stale cloud draft.
- [ ] State readiness separately: evidence assistant, freeform, CT scientific approval, APK build, real-device QA, production. Complete seven-point closure even when conditional gates correctly remain closed.
