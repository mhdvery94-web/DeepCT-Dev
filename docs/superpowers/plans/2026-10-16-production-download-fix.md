# Production prediction download hotfix

> Execute with superpowers:subagent-driven-development and TDD. Root owns Git commits and production operations. This ordinary isolated checkout was cloned from main2934814; it is not a worktree. Pending evidence/LLM work stays in /workspace/DeepCT-Dev.

**Goal:** Clicking either prediction archive download in Next.js downloads the ZIP without the free ngrok browser interstitial, including files above Vercel's response-body limit.

**Architecture:** Keep Laravel owner-scoped, expiring signed URLs. Next BFF prepares a signed URL as small JSON on an explicit prepare request. A same-origin service worker fetches that URL with `ngrok-skip-browser-warning` and streams its body to the browser download manager. No archive bytes pass through Vercel and no bearer token enters worker messages/URLs. Flutter already uses authenticated streamed HTTP with the ngrok header; verify it without needless changes.

**Tech Stack:** Next.js/TypeScript, browser Service Worker/Fetch streaming, Laravel CORS configuration, Node tests and Chromium functional acceptance.

**Spec:** Latest user instruction prioritizes the production download bug, then resumes points1–7. Screenshot shows the ngrok free interstitial for /api/downloads/predictions/5/results. Official ngrok docs https://ngrok.com/docs/pricing-limits/free-plan-limits confirms the bypass is a request header, not a query parameter. Current production Next anchors cause BFF307 to ngrok and lose the header.

## Global Constraints

- Isolate from all pending develop features. Do not activate LLM or any CT candidate; preserve user data, authentication, owner checks, expiry, signatures and range downloads.
- Preserve HTTPS verification and Vercel protection; do not change ngrok plan, domain, user-agent globally or introduce another tunnel.
- Archives stream directly from Raspi/ngrok in browser; never unconditionally buffer gigabytes or stream large ZIPs through a Vercel function.
- Service-worker route is narrowly scoped, no caching/interception of unrelated requests. No tokens, URLs or capability queries in logs.
- Root owns index, commits, review, production deployment and scoped runtime configuration. Implementer does not commit, deploy or spawn agents.

## Review Focus

1. Fresh Chromium profile without an ngrok visit cookie must receive ZIP bytes and matching digest, not HTML.
2. Both results/complete links and list/detail actions must use the fixed flow; errors stay visible and do not navigate away.
3. Foreign paths, missing/malformed signed links, expired links and account revocation must not bypass Laravel protection or yield HTML saved as ZIP.
4. Download length exceeds4.5MiB and streaming stays bounded; no fallback silently buffers unlimited bytes. If Service Worker unsupported, only a strictly bounded small-file fallback is permitted, with explicit error for larger downloads.
5. Worker startup/controller race, range206 headers, unexpected redirects and network failures must clean up ephemeral state and produce a recoverable error.

### Task 1: Fix Next.js browser download transport

**Files:** Modify `fe_web/src/app/api/backend/[...path]/route.ts`, `fe_web/src/components/prediction-workspace.tsx`, `be/config/cors.php`; create focused `fe_web/src/lib/prediction-download.ts`, `fe_web/src/components/prediction-download.tsx`, `fe_web/public/prediction-download-sw.js`, and tests in `fe_web/tests/` (and browser helper as needed). No dependency changes.

**Interfaces and exact behavior:** Existing GET `/api/backend/predictions/{id}/download/{results|complete}` keeps its ordinary redirect behavior for compatibility, but explicit `?prepare=1` returns small authenticated JSON `{success:true,data:{url,filename}}`; filename is deterministic safe `results_<id>.zip`/`complete_<id>.zip`. Build public URL preserving API deployment prefix and the exact signed query; accept only the expected internal path for this id/kind, no arbitrary origin/path. Signed query is not modified to add a pretend ngrok bypass parameter. No bearer token leaves BFF. Existing backend owner-scoped download-link generation is reused.

`startPredictionDownload(path:string):Promise<void>` (or equivalently named focused helper) obtains prepare JSON, registers `/prediction-download-sw.js` with root scope, awaits readiness and MessageChannel registration acknowledgement with bounded timeout, then clicks a hidden same-origin download anchor to a narrow ephemeral worker endpoint. Worker accepts registration messages only from same-origin window clients, validates signed target path/query/type and http(s) URL, stores a cryptographically random handle only temporarily in a bounded map, and intercepts only its own exact download route. Fetch target with `ngrok-skip-browser-warning:true`, `credentials:omit`, no authorization, `redirect:error` (or equally strict validated redirect discipline). Reject upstream HTML/non-ZIP/error responses. Return upstream stream with safe attachment filename, correct ZIP content type and necessary length/range/checksum headers; never concatenate the body. Preserve at least normal whole-file downloads and Range206 semantics. Avoid persisting capability URLs. Keep records long enough for browser range retries within signature expiry, prune expired entries and bound their number.

Replace every list/detail results/complete anchor with an accessible button/component that starts this helper, disables repeat clicks during preparation, reports errors (aria-live) and preserves page location. If a worker cannot start, report that failure. A small-file fallback is optional and must be strictly bounded (maximum32MiB); never fake a successful download or suggest clicking the ngrok warning as the fix. Root can narrow unsupported-browser claims after actual validation.

Expose necessary public file headers in Laravel CORS (`Content-Disposition`, `Content-Length`, `Content-Range`, `Accept-Ranges`) alongside existing digest headers; keep authentication/origin policy otherwise unchanged. Do not modify the signed route/controller unless a concrete reproducible defect requires it.

- [ ] Write meaningful failing tests for prepare validation/prefix/query, worker header and streaming, HTML/error rejection, source/target validation, one-time startup/race, TTL/map bound/range headers, client error handling; save RED evidence.
- [ ] Implement the focused fix with no production feature imports. Worker JavaScript lint/type hygiene must pass repository checks.
- [ ] Add/run a Chromium browser acceptance with a fresh profile, mock cross-origin backend requiring the ngrok header, ZIP payload >4.5MiB, both archive kinds and unchanged page URL. Verify byte digest, no giant blob buffer path, scope isolation and error path. Root will additionally validate actual production/ngrok with owned fixtures.
- [ ] Run Next unit/lint/typecheck/build using Node22 where required. Build uses explicit local fixture API; no human data or production secrets. PHP config syntax/headers validation through prepared Docker PHP is sufficient for additive CORS config.
- [ ] Self-review and write full RED/GREEN and exact files/commands/results/limits to this plan workspace task-1-report.md. Return concise status. Root commits and dispatches independent task review/fixes and final broad review for this focused branch.

### Task 2: Review, production rollout and resume original plan (root)

- [ ] Review only this hotfix branch and handle actionable findings with implementer/scoped review. Stage old production code/config backups and verify queue/runtime before changes.
- [ ] Deploy only required production CORS config with backup/readiness/rollback (if needed), preserve all .env/secrets and app/model settings. Create identified temporary production download fixtures instead of reading/replacing human prediction data.
- [ ] Verify original warning in fresh real Chromium and successful fixed download from actual ngrok, ZIP structure/digest, size above4.5MiB, results/complete, owner/expiry errors. Remove only owned test users/files/tokens. Preserve real analysis files.
- [ ] Promote only reviewed hotfix to main, verify Next production deployment/alias and public actual download. Do not blindly run the broad Release workflow (which can deploy backend/reset accounts).
- [ ] Port the isolated fix into develop/staging, resolve differences while retaining new evidence source, synchronize laptop without losing edits/stash; archive a recovery report. Then resume original evidence plan at Task2 review, Task4 benchmark/APK, Task3 UI, Task5 rollout/closure. Do not redispatch completed metrics.
