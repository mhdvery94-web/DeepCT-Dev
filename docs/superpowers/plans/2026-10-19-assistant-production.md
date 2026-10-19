# Assistant production release plan

Spec: docs/superpowers/specs/2026-10-19-assistant-production.md
Base develop153ef5f; main d261711. Existing checkout only; no worktree.

1. Root verifies actual production preview/download, reuses only owned synthetic fixtures and cleans them.
2. Implementer repairs grounded replies and metadata-specific frontend wording. Add meaningful RED/GREEN regression tests for wrong topic, safe scope, float formatting/tiny nonzero values, baseline direction, model historical identity/missing version and scientific uncertainty. Keep provider payload/schema and GPU policy. Independent task review required.
3. Root runs integration, staged actual API/browser acceptance, creates isolated production source subset and migration/queue deployment plan, obtains final review, then deploys and verifies production. Sync per-branch source to Windows with stash preservation and save recovery/checklist.

Global constraints: one implementation agent at a time; root alone commits/pushes/changes remote systems. No new dependencies, TLS/checksum bypass, arbitrary model activation, GPU killing, unrelated UI overhaul or unbounded freeform. Only own temporary QA data may be cleaned. Preserve working tree/user edits and credentials. Record rulings and remaining gates honestly.
