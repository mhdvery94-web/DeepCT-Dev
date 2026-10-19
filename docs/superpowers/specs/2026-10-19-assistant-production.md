# Production prediction assistant

User authorizes production preview/download correction and repairing the prediction assistant until suitable for production. Existing main d261711 already contains isolated preview/download changes; verify its serving deployment before making another release.

Production assistant scope is evidence-grounded Indonesian explanations of the signed-in user's CT results, metrics, stored model identity, process state and controlled SOP. LLM prose is not trusted evidence and unrestricted generation remains closed after measured failures. CT scientific approval is independent.

Required fixes: readable short paragraphs instead of raw floating-point artifacts; explicit correct better/worse/equal baseline directions; bounded model snapshot identity/version distinct from document versions; clear snapshot versus current-state caveat; source-derived missingness and no fabricated scientific verdict. Topic classifier must not override explicit question intent or cross-owner/secret boundaries. Preserve current provider wire schema, cancellation/publication boundary, timeout/lease, ownership, tri-state context and immutable retries.

Production release must add only assistant/evaluation prerequisites, additive migrations and dedicated queue worker/config. Preserve users, production credentials/storage, active CT processing, model activation and unrelated upload-management features. Verify exact source, backup/rollback, DB migrations and actual both-role web/API canary before reporting activation. Do not run existing destructive model/data seeders or broad release jobs as a shortcut. Retain ngrok warning-header download fix and combined PNG gallery.

Build/test evidence and real bounded acceptance decide readiness; no test disabling, no automatic quality approval or fabricated benchmark passage. Default configuration remains off; production-specific activation follows successful staged rollout. Existing develop/staging/main publication and local sync are explicitly authorized by the session and latest request; no redundant permission menu.
