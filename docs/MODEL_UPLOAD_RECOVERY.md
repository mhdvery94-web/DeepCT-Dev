# Retained model upload recovery

Laravel remains the owner and administrator authorization boundary. Model bytes
use direct HTTPS TUF capabilities. Control and inference credentials never enter
either client; publication and availability remain separate operations.

Clients submit the strict manifest plus a UUID `creation_key` to
`POST /api/admin/model-uploads`. The same key must accompany an exact manifest
retry. Laravel commits an owner-bound `creating` row and a separate server intent
UUID before contacting TUF. Reusing a key with another manifest returns 409.
TUF receives the server UUID in `Idempotency-Key`, persists it with its session,
and replays that exact session before checking version/disk reservations. Replay
does not rotate or return a capability; transfer obtains one with the owned renew
route. Another administrator's key creates a distinct intent and cannot claim
an existing reservation.

A lost response or failed local attachment leaves the owned intent discoverable.
Selecting it calls `GET /api/admin/model-uploads/{id}`, which completes the same
creation intent and attaches the original UUID. Both clients retain the creation
key for transient retries and support selecting a pending intent after reopening.
This cannot retroactively identify orphan sessions created by older code without
an intent; do not claim a session based only on its model/version tuple.

Listing uses `page` (positive integer) and optional `search` (at most 80 characters,
matching model ID or version literally). Each response contains at most 50 owned
rows and `pagination: {current_page, last_page, total, per_page}`. Both clients
provide previous/next navigation and search; selection retains its identity when
the list page changes. Legacy managed model toggle/delete remains blocked.

Availability changes commit a fail-closed desired-target barrier before sending
a mutation. The same target may retry using the same positive revision; a
conflicting target returns 409. TUF persists revision ordering before changing
activation: duplicate completion is idempotent, older revisions cannot reverse a
newer target, and requests without a revision are rejected after revisioned use.
Older Laravel barriers receive a revision on their first same-target retry.
Polling an old worker state alone never clears the barrier. Pending/processing
CT jobs still block changes.

Accounts owning any retained upload, including pending, failed, cancelled, or
published sessions, return intentional 409 before account cleanup. The user delete
hook enforces the guard for API and Eloquent deletion. Account deletion and new
creation intents take the same owner row lock. Retain ownership and immutable
published weights; do not weaken the FK or remove sessions to bypass this policy.

Deploy the updated TUF control contract, then apply the additive
`2026_10_14_060000_add_model_upload_recovery` migration to the isolated staging
backend before using the updated Laravel/clients. Existing upload rows and unique
TUF IDs remain intact. Migration rollback is rejected while any upload row is retained, before changing
metadata or indexes. Roll back application code while preserving this migration
and its recovery data.
AI stays disabled by default and these changes do not authorize production rollout.
