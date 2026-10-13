# Opt-in isolated Task 6 acceptance

These scripts use real Laravel/MySQL, Next BFF, TUF HTTP routes, queues and
Chromium. Only numerical model execution and the LLM provider are synthetic.
They never load TensorFlow/GPU or call production. This is integration evidence;
public ingress, arbitrary-upload containment, scientific tolerance and Pi LLM
quality require separate acceptance. Run one harness at a time.

Existing cloud prerequisites: running `deepct-api` container and MySQL, Node
22.23.3, `/workspace/.model-server-venv`, `/workspace/.browser-tools` with
`playwright-core`, and `/usr/bin/chromium`. No new dependency install is needed.
Runtime files are private under `/workspace/.deepct-runtime/task6`, outside git.
Laravel storage is ignored `be/storage/task6`; only `db_aict_task6` is allowed.
Do not print `.env`, account passwords, cookies, capabilities or signed URLs.

From `/workspace/DeepCT-Dev`:

```bash
/workspace/.model-server-venv/bin/python be/tests/Acceptance/prepare.py
docker exec --user 1000:1000 --env-file /workspace/.deepct-runtime/task6/laravel.env -w /workspace/DeepCT-Dev/be deepct-api php tests/Acceptance/database.php
docker exec --user 1000:1000 --env-file /workspace/.deepct-runtime/task6/laravel.env -w /workspace/DeepCT-Dev/be deepct-api php tests/Acceptance/console.php migrate --force
docker cp /workspace/.deepct-runtime/task6/accounts.json deepct-api:/tmp/task6-accounts.json
docker exec --user 1000:1000 --env-file /workspace/.deepct-runtime/task6/laravel.env -w /workspace/DeepCT-Dev/be deepct-api php tests/Acceptance/seed.php > /workspace/.deepct-runtime/task6/seed.json
chmod 600 /workspace/.deepct-runtime/task6/seed.json
```

Inspect listeners/processes before starting; reuse the existing isolated PHP
server on container port 8016. Stop/restart only your own harness processes.
Never stop the unrelated API or queue worker. Run these long-lived commands in
separate terminal sessions, from the repository root:

```bash
docker exec --user 1000:1000 --env-file /workspace/.deepct-runtime/task6/laravel.env -w /workspace/DeepCT-Dev/be deepct-api php -S 0.0.0.0:8016 tests/Acceptance/router.php
/workspace/.model-server-venv/bin/python deepct-model-server/tests/acceptance_worker.py --runtime /workspace/.deepct-runtime/task6
docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' deepct-api
# Replace the IP below with the preceding container IP.
/workspace/.model-server-venv/bin/python be/tests/Acceptance/ingress.py --upstream 172.18.0.3:8016 --runtime /workspace/.deepct-runtime/task6
```

Ingress listens on 9016 and TLS 9446. It strips `/staging` to Laravel, `/tuf` to
the fixture worker on 9116, and traps any root production fallback with 418.
It records upload header names only. The generated certificate is local and
valid for two days; recreate expired certificate/key together using `prepare.py`.
Do not disable TLS verification for external destinations.

From `fe_web`, build and start production Next on 3016, with the local CA added
to Node's trust store. Do not build into `.next` while a dev server uses it.

```bash
env LARAVEL_API_BASE_URL=https://localhost:9446/staging/api NODE_EXTRA_CA_CERTS=/workspace/.deepct-runtime/task6/cert.pem npx --offline -y -p node@22.23.3 -c 'npm test && npm run check && npm run build'
env LARAVEL_API_BASE_URL=https://localhost:9446/staging/api NODE_EXTRA_CA_CERTS=/workspace/.deepct-runtime/task6/cert.pem npx --offline -y -p node@22.23.3 -c 'npm run start -- --hostname 0.0.0.0 --port 3016'
env TASK6_RUNTIME=/workspace/.deepct-runtime/task6 npx --offline -y -p node@22.23.3 -c 'node tests/acceptance-http.mjs all'
```

Modes `prefix`, `history`, `flows` may be run individually. The script creates
synthetic uploads, conversations and CT results in the isolated DB/storage;
queue commands stop after draining only `llm`/`task6-ct`. Accounts are restored
after revocation tests and outage marker files removed in `finally` blocks.
Persisted private browser states allow repeat runs without repeated login.
Screenshots go under the private runtime's `output/playwright/`; never commit
browser state, `.incoming` uploads, generated weights or runtime credentials.
Repeated runs retain synthetic sessions/history; clean only this harness's
resources if needed. The script is intentionally excluded from `npm test`.
