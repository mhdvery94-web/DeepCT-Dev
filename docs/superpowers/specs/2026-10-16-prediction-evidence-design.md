# Prediction evidence and assistant readiness

The user approved the six previously discussed steps and requested points 1–7. The seventh step is delivery, synchronization, and an evidence-based release decision. This document records implementation choices made by the builder within that authorization. It does not confer scientific approval.

## Outcome and boundaries

Keep Laravel as the authority for owners, analysis status, stored measurements, and chat admission. Keep Next.js and Flutter as clients of that same API. Improve the existing staging assistant without changing production activation or replacing the working legacy CT model. Never use an LLM to calculate a metric, read private paths, execute commands, or decide scientific acceptance.

## 1. Evaluation report

Retain the existing `analysis_records.validation` JSON and its flat numeric keys for compatibility. New runs add a versioned evaluation envelope inside that JSON: `schema_version`, `evaluation_status` (`completed`, `no_reference`, `evaluation_failed`), safe `reason_code`, numeric midpoint provenance, model snapshot, method parameters, PSNR and SSIM availability, and baseline measurements. No reference means that the original uploaded frames contain no valid held-out midpoint, not that the interpolation failed. Measurement failure must never destroy otherwise completed interpolation outputs. Legacy reports lacking the envelope are explicitly `legacy_unknown`; do not invent a failure cause.

Use raw decoded uint16 pixels, data range 65535, no independent image normalization. PSNR at exactly zero MSE is represented by JSON null plus `psnr_status=infinite`, distinct from unavailable. A finite rounded zero MAE alone never proves identical pixels. Errors exposed to the assistant use allowlisted reason codes only, not exceptions, filenames, paths, or response bodies.

## 2. Metrics and baseline

Add local-window SSIM using a 7×7 uniform window, sample covariance, K1=0.01, K2=0.03, cropped valid centers, data range 65535; no resampling. Images smaller than the window keep MAE/RMSE/PSNR and declare SSIM unavailable with `image_too_small`. Match independent scikit-image reference fixtures. Reject evaluation width above 4096 before allocating SSIM arrays; report measurement failure while retaining completed interpolation outputs. This explicit resource limit is a builder choice discovered during memory review. Compute in bounded memory suitable for the 512 MiB PHP worker; do not unpack entire 2048² frames into PHP arrays.

Measure a linear midpoint baseline against the same uploaded held-out reference and with the identical metric method. Baseline pixel rounding is half upward, `floor((left+right+1)/2)`. Record comparison deltas and whether each metric improves, ties, or regresses, without asserting scientific adequacy. A baseline failure is separate from model-evaluation failure. Existing uploaded frames alone are reference truth; synthetic output must never become held-out truth.

## 3. Context and documents

Expose an authenticated owner-scoped analysis-evidence endpoint using the same sanitizer as assistant context. Snapshot the evidence used per reply. Supply a small, versioned, curated Indonesian SOP corpus: evaluation/reference, metric conventions, status/start, expiry, model version/approval. Initially retrieve deterministically by topic/term match; no embeddings, Redis, uploaded arbitrary documents, external search, or TIFF text extraction. Distinguish document citations from dynamic analysis evidence in both clients.

Follow-ups omitting `analysis_record_id` inherit the last selection in the same owned conversation. Explicit null clears context. Explicit new ID switches context after owner checks. Resolve inside serialized admission; preserve idempotency semantics including retries after later context switches. Never infer selection from another conversation or user. Old stored source snapshots remain labeled as snapshots; no claim that they are live state.

Metadata mode remains the safe default on staging: the model chooses a topic and the server renders exact facts and retrieved documentation. Invalid provider topic output falls back to a deterministic safe overview, rather than exposing model prose. Freeform generation is a separate evaluation-only experiment until its quality gate passes.

## 4. Real GPU comparison

Compare the existing pinned DeepSeek R1 7B with Qwen2.5 7B Instruct Q4_K_M if its verified Ollama artifact and runtime fit the current GPU. This is a builder choice based on the 8 GB TUF GPU and existing Ollama 0.11.4. Download through normal verified HTTPS; preserve manifest and blob digests. No paid API or external research-data transmission is required.

Run actual local generation under the existing shared GPU lease and verified unload discipline, serially with legacy CT access. Preserve the legacy process and other users' jobs; enough free VRAM is preferable to stopping anything. Candidate runs use synthetic but representative owned metadata and curated documentation, never private TIFF bytes. Capture final answer and timing only; do not publish reasoning traces. No arbitrary frontend model or provider URL is introduced.

## 5. Quality gate

Maintain 40 representative cases covering numbers including zero, finite/infinite/missing metrics, no reference, evaluation failure, baseline regressions, status, scientific uncertainty, expiry, missing model version, follow-ups, documents, prompt injection, and cross-owner requests. Evaluate each model's freeform output against explicit expected facts and manually review all retained final answers. Record the numerical rule-check results separately from human semantic review; neither proves general correctness.

Activation requires all critical factual/privacy/unsupported-claim cases to pass, sources to match, no fabricated failure cause, and no scientific approval claim. A failed generative gate keeps metadata mode active, documents the failure, and still delivers the improved evidence assistant. A researcher must separately approve any scientific interpretation and the CT candidate; absent a researcher threshold, do not label a CT model scientifically ready.

## 6. Staging acceptance

Exercise real Laravel queue/API and browser flows in Next.js and Flutter Web for admin and researcher, including missing/failed evaluations, SOP evidence, context inheritance/clear/switch, ownership isolation, and all new report states. Build a staging APK with the staging API and isolated package identity using a dedicated workflow, never a manual production release workflow. Verify artifact identity and provenance. Attempt physical Android testing only if an authorized device is available; absence of a device is reported as unverified, not passed. Do not turn off Vercel protection or promote main solely to obtain an APK.

## 7. Delivery

Use the existing develop checkout without a worktree. Review implementation, run relevant suites once at final integration, and deploy only reviewed staging changes. Push develop/staging and synchronize the user's existing Windows checkout with non-destructive fast-forward logic, preserving the existing stash and any new local changes. Save reports, recoverable source bundle, checksums, and reusable non-secret helper instructions. Production stays unchanged unless all applicable gates and any needed scientific review are complete. Existing cloud startup-guide persistence has a known stale-draft error; preserve the complete proposal rather than retrying the stale write.

## Addendum — combined prediction preview (user request, 2026-10-16)

After a completed prediction, the Next.js result preview should show the uploaded input and generated output together in frame-number order, like the existing Flutter gallery. Generated frames must carry a visible AI badge; uploaded frames remain labeled Input. The builder chooses a combined default with separate Input/AI filters, keeping scrub/play/navigation, paged thumbnails, responsive layout and download actions. This is a sequence of existing display PNG previews, not a new averaged image or a change to TIFF files or model inference. Use authoritative API frame.kind (output versus input), not gaps in filenames, to assign labels. Keep same-number frames of different kinds distinguishable using the existing kind-specific preview request. Invalid/unknown kinds must never acquire a fabricated AI label.

The existing authenticated owner-scoped frames/preview endpoints suffice. Preserve backend owner checks, result expiry behavior, data, download hotfix and mobile Flutter behavior. A new original/generated distinction must not imply scientific quality or researcher approval. Validate numeric ordering, labels, filtering/navigation, empty/loading/error transitions and actual browser rendering at desktop/tablet/mobile widths. Publish with the already authorized develop/staging feature delivery; production promotion remains limited to the separately authorized download hotfix unless the user requests more.
