# Production assistant deployment candidate

These units are reviewed source only. Installing them does not authorize enabling
production. The assistant remains disabled by default. Do not change the existing
Ollama service, binary, model store, CT worker or production `.env` by copying an
example wholesale. Model upload endpoints and UI are outside this promotion.

The dedicated Ollama daemon uses the existing `/usr/local/bin/ollama`, runs as
`ollama:ollama`, reuses `/usr/share/ollama/.ollama/models`, and binds only
`127.0.0.1:11436`. It is a bounded topic classifier: Laravel renders the answer
from authorized evidence. Configure the API and dedicated queue worker with the
same reviewed backend settings, using the existing secret/configuration workflow:

```dotenv
AI_ASSISTANT_ENABLED=false
AI_METADATA_MODE=true
AI_OLLAMA_BASE_URL=http://127.0.0.1:11436
AI_ASSISTANT_MODEL=deepseek-r1:1.5b
AI_OLLAMA_GATEWAY=false
AI_CONTEXT_TOKENS=16384
AI_OUTPUT_TOKENS=128
AI_THREADS=2
AI_LOCK_STORE=file
```

Use the already pinned production `deepseek-r1:1.5b` artifact; verify its digest
against the deployment record before use. Do not silently pull or replace a tag.
No provider token is needed on the dedicated local loopback endpoint; keep any
existing credentials in the production secret store. API and worker must share
the same atomic lock store and writable Laravel storage. Verify the actual PHP
binary, `jihyo` user and `/var/www/deepct-ai` checkout on the host first.

The daemon permits one request and one loaded model, unloads with keep-alive 0,
and is configured with CPUQuota 200%, Nice 10, TasksMax 128 and MemoryMax 3G.
**The actual Pi kernel has no memory controller, so MemoryMax is not enforced.**
RSS is not zero or established by the unit file. Root must measure process RSS
through a full API canary and review headroom alongside the existing workload.
The CPU profile previously observed approximately 19–20 seconds for classifier
requests and 118 API health samples with zero failures; those observations alone
do not establish complete application acceptance or memory safety. Full canary
answer/privacy review, peak RSS review, backup and schema review, exact-source CI,
and explicit final activation remain deployment gates. Native APK/store rollout
and physical device validation are outside this task.

Schema prerequisite: preserve migration identities
`2026_10_10_010000_create_ai_assistant_tables`,
`2026_10_11_010000_preserve_ai_request_analysis_selection`, and
`2026_10_11_120000_add_managed_model_uploads`. The last migration provides the
immutable analysis model snapshot; its dormant registry columns and model_uploads
table are schema prerequisites only. It does not enable model uploads. Review a
backup and migration SQL/status before applying pending migrations. Do not replay
historical migrations, run a destructive fresh migration, purge models or seed.

After source, backup, schema and canary gates are cleared, install only these two
new units (commands below never overwrite `.env` or the existing Ollama unit):

```sh
sudo install -m 0644 be/deploy/production/deepct-assistant-ollama.service /etc/systemd/system/deepct-assistant-ollama.service
sudo install -m 0644 be/deploy/production/deepct-assistant-llm.service /etc/systemd/system/deepct-assistant-llm.service
sudo systemctl daemon-reload
sudo systemctl enable --now deepct-assistant-ollama.service
sudo systemctl enable --now deepct-assistant-llm.service
```

Starting the worker with `AI_ASSISTANT_ENABLED=false` is preparatory only. Check
loopback `/api/tags`, verify the pinned artifact, and run the agreed authenticated
full API canary under the selected production configuration before activation.
Confirm queued assistant work runs only on connection `llm`, queue `llm` with
300-second timeout, one try, 256 MB PHP worker recycling and 360-second lease.
The separate CT database queue retains at least 7260 seconds for its 7200-second
job timeout. API and queue workers need a controlled restart after config changes;
never kill an in-flight CT job to activate the assistant.

Rollback activation by setting `AI_ASSISTANT_ENABLED=false` through the existing
configuration workflow and refreshing API/worker configuration. Drain or explicitly
cancel pending assistant requests before stopping the dedicated worker and daemon.
Retain additive schema/data and the existing CT service; do not roll back unrelated
migrations or remove model artifacts. No remote commands were run for this source
assembly.
