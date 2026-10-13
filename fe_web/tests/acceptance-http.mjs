// Explicit opt-in smoke script; excluded from npm test's *.test.mjs glob.
// Requires isolated Laravel/TUF/Next processes described in tests/Acceptance.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile, access, unlink } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { execFileSync, execFile } from 'node:child_process';
import { promisify } from 'node:util';
import https from 'node:https';
import path from 'node:path';

const runtime = process.env.TASK6_RUNTIME;
assert(runtime?.startsWith('/workspace/.deepct-runtime/'), 'Use the private disposable runtime directory');
const requireBrowser = createRequire('/workspace/.browser-tools/package.json');
const { chromium } = requireBrowser('playwright-core');
const { unzipSync } = createRequire(import.meta.url)('fflate');
const origin = 'http://localhost:3016';
const ingress = 'https://localhost:9446';
const mode = process.argv[2] ?? 'all';
const seed = JSON.parse(await readFile(path.join(runtime, 'seed.json'), 'utf8'));
const accounts = JSON.parse(await readFile(path.join(runtime, 'accounts.json'), 'utf8'));
const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true, args: ['--no-sandbox'] });
let assertions = 0;
const check = (condition, description) => { assert(condition, description); assertions++; console.log(`PASS ${description}`); };
const contexts = [];
const execute = promisify(execFile);
const consoleArgs = ['exec', '--user', '1000:1000', '--env-file', path.join(runtime, 'laravel.env'),
  '-w', '/workspace/DeepCT-Dev/be', 'deepct-api', 'php', 'tests/Acceptance/console.php'];
const seedArgs = [...consoleArgs.slice(0, -1), 'tests/Acceptance/seed.php'];

async function waitFor(operation, expected, description) {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    const result = await operation();
    if (expected(result)) return result;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error(`Timeout: ${description}`);
}

async function login(role) {
  const saved = path.join(runtime, `${role}-browser.json`);
  const hasSaved = await access(saved).then(() => true, () => false);
  const context = await browser.newContext({ viewport: { width: 1366, height: 900 },
    // Only the disposable local certificate. Public TLS remains a separate gate.
    ignoreHTTPSErrors: true, ...(hasSaved ? { storageState: saved } : {}) });
  contexts.push(context);
  const page = await context.newPage();
  if (!hasSaved) {
    await page.goto(`${origin}/login`);
    await page.getByLabel('Email', { exact: true }).fill(`${role}@task6.test`);
    await page.getByLabel('Password', { exact: true }).fill(accounts.password);
    await page.getByRole('button', { name: 'Login', exact: true }).click();
    await page.waitForURL('**/dashboard', { timeout: 30_000 });
    await context.storageState({ path: saved });
  }
  const session = await context.request.get(`${origin}/api/auth/session`);
  check(session.status() === 200, `${role} real HttpOnly BFF session`);
  const cookie = (await context.cookies()).find(item => item.name === 'deepct_session');
  check(cookie?.httpOnly === true, `${role} auth cookie HttpOnly`);
  return { context, page };
}

async function bff(client, route, method = 'GET', body) {
  return client.context.request.fetch(`${origin}/api/backend${route}`, {
    method, headers: { origin, accept: 'application/json' },
    ...(body === undefined ? {} : { data: body }), maxRedirects: 0,
  });
}

async function prefix(client) {
  const response = await bff(client, `/predictions/${seed.record}/download/results`);
  check(response.status() === 307, 'actual BFF returns owned signed archive redirect');
  const location = new URL(response.headers().location);
  check(location.pathname === `/staging/api/downloads/predictions/${seed.record}/results`, 'signed redirect preserves isolated API prefix');
  const archive = await client.context.request.get(location.href);
  check(archive.status() === 200, 'real prefixed Laravel signature verifies');
  const bytes = await archive.body();
  check(bytes.length > 4.5 * 1024 ** 2, 'large archive exceeds function streaming limit');
  const files = unzipSync(bytes);
  check(createHash('sha256').update(files['frame_002.tif']).digest('hex') === seed.sha256, 'archive returns exact owned payload bytes');
  const tampered = new URL(location);
  tampered.searchParams.set('owner', String(seed.users.other));
  check((await client.context.request.get(tampered.href)).status() === 403, 'tampered owner signature rejected');
  const expired = execFileSync('docker', ['exec', '--user', '1000:1000', '--env-file', path.join(runtime, 'laravel.env'),
    '-w', '/workspace/DeepCT-Dev/be', 'deepct-api', 'php', 'tests/Acceptance/seed.php', 'expired-link'], { encoding: 'utf8' });
  check((await client.context.request.get(`${ingress}/staging${expired}`)).status() === 403, 'valid but expired signature rejected');
  check((await client.context.request.get(`${ingress}/api/downloads/anything`)).status() === 418, 'root ingress traps accidental production path');
  const news = await (await bff(client, '/news')).json();
  const image = await bff(client, news.data[0].image_url);
  check(image.status() === 200 && (await image.body()).subarray(1, 4).toString() === 'PNG', 'actual BFF image media bytes under prefix');
  const media = await bff(client, news.data[0].video_url);
  check(media.status() === 200 && (await media.body()).toString() === 'synthetic-media-bytes', 'actual BFF media returns exact isolated bytes');
  const asset = await client.context.request.get(`${origin}/assets/BRIN.png`);
  check(asset.status() === 200 && (await asset.body()).subarray(1, 4).toString() === 'PNG', 'Next static asset loads alongside prefixed API');
}

async function history(client, role, widths = [1366, 768, 390]) {
  for (const width of widths) {
    await client.page.setViewportSize({ width, height: 900 });
    await client.page.goto(`${origin}/workspace/assistant`);
    await client.page.getByText('Riwayat pribadi akun Anda').waitFor({ state: width <= 900 ? 'attached' : 'visible' });
    if (width <= 900) await client.page.getByRole('button', { name: 'Riwayat percakapan', exact: true }).click();
    await client.page.getByRole('button', { name: `Task 6 ${role} history`, exact: true }).click();
    await client.page.locator('.assistant-message').last().waitFor();
    await client.page.locator('.assistant-older').scrollIntoViewIfNeeded();
    const message = client.page.locator('.assistant-message').first();
    const label = await message.locator('button').getAttribute('aria-label');
    const before = await message.boundingBox();
    await client.page.getByRole('button', { name: 'Pesan lebih lama', exact: true }).click();
    await client.page.waitForFunction(() => document.querySelectorAll('.assistant-message').length === 40);
    const anchored = client.page.locator('.assistant-message').filter({ has: client.page.getByRole('button', { name: label, exact: true }) });
    const after = await anchored.boundingBox();
    check(Math.abs(after.y - before.y) <= 2, `${role} older history preserves viewport anchor at ${width}px`);
    check(await client.page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), `${role} no document horizontal overflow at ${width}px`);
    await mkdir(path.join(runtime, 'output/playwright'), { recursive: true });
    await client.page.screenshot({ path: path.join(runtime, `output/playwright/${role}-${width}.png`) });
  }
}

async function uploads(admin, user) {
  const bytes = await readFile(path.join(runtime, 'models/task6-ct/1.0.0/model.h5'));
  const original = JSON.parse(await readFile(path.join(runtime, 'models/task6-ct/1.0.0/manifest.json'), 'utf8'));
  const unique = `task6-${Date.now()}`;
  check((await bff(user, '/admin/model-uploads', 'POST', { ...original, model_id: unique })).status() === 403, 'researcher cannot create model upload');
  check((await bff(admin, '/admin/model-uploads', 'POST', original)).status() === 409, 'real immutable duplicate model/version rejected');

  await Promise.all([
    admin.page.waitForResponse(response => response.url().endsWith('/api/backend/admin/model-uploads') && response.request().method() === 'GET'),
    admin.page.goto(`${origin}/admin/models`),
  ]);
  await admin.page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const panel = admin.page.locator('.model-upload-panel');
  await panel.getByLabel('ID model', { exact: true }).fill(unique);
  await panel.getByLabel('Versi immutable (contoh 1.0.0)', { exact: true }).fill('1.0.0');
  await panel.getByLabel('Nama tampilan', { exact: true }).fill('Synthetic interrupted upload');
  check(await panel.getByLabel('ID model', { exact: true }).inputValue() === unique, 'hydrated upload form retains declared model identity');
  let chunks = 0;
  let blocked;
  const reachedSecond = new Promise(resolve => { blocked = resolve; });
  await admin.page.route('**/tuf/uploads/**', async route => {
    if (route.request().method() !== 'PUT') return route.continue();
    const headers = route.request().headers();
    check(!headers.cookie, 'direct TUF browser request carries no Laravel cookie');
    const authCookie = (await admin.context.cookies()).find(item => item.name === 'deepct_session');
    check(headers.authorization !== `Bearer ${authCookie.value}`, 'direct TUF request uses scoped capability, not Laravel bearer');
    if (++chunks === 2) { blocked(route); return; }
    await route.continue();
  });
  await panel.locator('input[type=file]').setInputFiles(path.join(runtime, 'models/task6-ct/1.0.0/model.h5'));
  await panel.getByRole('button', { name: 'Hash & upload', exact: true }).click();
  let watchdog;
  const second = await Promise.race([reachedSecond, new Promise((_, reject) => {
    watchdog = setTimeout(async () => {
      console.log('Upload UI diagnostics:', await panel.locator('[role=alert], [role=status]').allTextContents());
      console.log('Form validity diagnostics:', await panel.locator('input,textarea').evaluateAll(elements => elements.filter(item => !item.validity.valid).map(item => [item.name, item.validationMessage])));
      reject(new Error('Actual browser upload did not reach the second chunk within 30 seconds'));
    }, 30_000);
  })]);
  clearTimeout(watchdog);
  await panel.getByRole('button', { name: 'Jeda upload', exact: true }).click();
  await second.abort('failed');
  await panel.getByRole('alert').filter({ hasText: 'Upload dijeda' }).waitFor();
  await admin.page.unroute('**/tuf/uploads/**');
  const list = (await (await bff(admin, '/admin/model-uploads')).json()).data;
  const saved = list.find(item => item.manifest.model_id === unique);
  const partial = (await (await bff(admin, `/admin/model-uploads/${saved.id}`)).json()).data;
  check(partial.offset === 4 * 1024 ** 2 && partial.state === 'uploading', 'interrupted actual browser upload commits only first chunk');
  // Reload models to prove durable session resumes after component/client restart.
  await Promise.all([
    admin.page.waitForResponse(response => response.url().endsWith('/api/backend/admin/model-uploads') && response.request().method() === 'GET'),
    admin.page.reload(),
  ]);
  await panel.getByRole('combobox').selectOption(String(saved.id));
  await panel.getByText('Pilih ulang file yang sama untuk resume', { exact: true }).waitFor();
  await panel.locator('input[type=file]').setInputFiles(path.join(runtime, 'models/task6-ct/1.0.0/model.h5'));
  await panel.getByRole('button', { name: 'Verifikasi & lanjutkan', exact: true }).click();
  await panel.getByText('Upload selesai', { exact: false }).waitFor();
  const complete = (await (await bff(admin, `/admin/model-uploads/${saved.id}`)).json()).data;
  check(complete.offset === bytes.length && complete.state === 'uploaded', 'real browser resumes exact bytes after reload and rehash');
  await panel.getByRole('button', { name: 'Validasi manifest & format', exact: true }).click();
  await waitFor(async () => (await (await bff(admin, `/admin/model-uploads/${saved.id}`)).json()).data,
    value => !value.operation && value.state === 'ready_for_test', 'real structural verification');
  check(true, 'real HDF5/hash verification reaches compatibility gate');
  await bff(admin, `/admin/model-uploads/${saved.id}/test`, 'POST', {});
  const unavailable = await waitFor(async () => (await (await bff(admin, `/admin/model-uploads/${saved.id}`)).json()).data,
    value => !value.operation && !!value.last_error, 'unconfigured compatibility fails closed');
  check(unavailable.state === 'ready_for_test' && !unavailable.published, 'unconfigured GPU containment prevents publication');
  await bff(admin, `/admin/model-uploads/${saved.id}/cancel`, 'POST', {});
  check((await (await bff(admin, `/admin/model-uploads/${saved.id}`)).json()).data.state === 'cancelled', 'real control cancellation persists');

  const mismatchResponse = await bff(admin, '/admin/model-uploads', 'POST', { ...original, model_id: `${unique}-bad`, sha256: '0'.repeat(64) });
  check(mismatchResponse.status() === 201, 'bad digest test creates independently declared upload');
  const mismatch = (await mismatchResponse.json()).data;
  const ca = await readFile(path.join(runtime, 'cert.pem'));
  for (let offset = 0; offset < bytes.length; offset += 4 * 1024 ** 2) {
    const chunk = bytes.subarray(offset, offset + 4 * 1024 ** 2);
    const code = await new Promise((resolve, reject) => {
      const request = https.request(mismatch.upload_url, { method: 'PUT', ca, headers: {
        authorization: `Bearer ${mismatch.token}`, 'Upload-Offset': String(offset),
        'Content-Type': 'application/octet-stream', 'Content-Length': String(chunk.length),
      } }, response => { response.resume(); response.on('end', () => resolve(response.statusCode)); });
      request.on('error', reject); request.end(chunk);
    });
    check(code === 200, 'capability-only actual HTTP chunk committed for bad-digest fixture');
  }
  await bff(admin, `/admin/model-uploads/${mismatch.id}/finalize`, 'POST', {});
  const rejected = await waitFor(async () => (await (await bff(admin, `/admin/model-uploads/${mismatch.id}`)).json()).data,
    value => !value.operation && value.state === 'failed', 'digest rejection');
  check(rejected.last_error === 'validation_failed' && !rejected.published, 'real hash mismatch fails without publication');
  execFileSync('docker', [...seedArgs, 'revoke-admin']);
  try {
    check((await bff(admin, `/admin/model-uploads/${mismatch.id}/renew`, 'POST', {})).status() === 403, 'revoked admin role rejects existing-session controls');
    check((await bff(admin, '/admin/model-uploads', 'POST', { ...original, model_id: `${unique}-revoked` })).status() === 403, 'revoked admin role rejects new model session');
  } finally { execFileSync('docker', [...seedArgs, 'restore-admin']); }
  await writeFile(path.join(runtime, 'worker-unavailable'), 'fixture outage');
  try {
    check((await bff(admin, '/admin/model-uploads', 'POST', { ...original, model_id: `${unique}-offline` })).status() === 503, 'unavailable real worker boundary returns controlled 503');
    check((await bff(user, '/predictions')).status() === 200, 'CT API remains available during upload-worker outage');
  } finally { await unlink(path.join(runtime, 'worker-unavailable')); }
}

async function chatAndCt(user, admin) {
  const conversation = (await (await bff(user, '/ai/conversations', 'POST', { title: 'Task 6 real queued chat' })).json()).data;
  check((await bff(admin, `/ai/conversations/${conversation.id}`)).status() === 404, 'admin cannot read researcher private assistant conversation');
  await user.page.setViewportSize({ width: 390, height: 900 });
  await user.page.goto(`${origin}/workspace/assistant?analysis_record_id=${seed.record}`);
  await user.page.getByRole('button', { name: 'Riwayat percakapan', exact: true }).click();
  await user.page.getByRole('button', { name: 'Task 6 real queued chat', exact: true }).first().click();
  await user.page.getByLabel('Pesan', { exact: true }).fill('Explain the owned synthetic CT result');
  const admission = user.page.waitForResponse(response => response.url().endsWith(`/ai/conversations/${conversation.id}/messages`) && response.request().method() === 'POST');
  await user.page.getByRole('button', { name: 'Kirim', exact: true }).click();
  const admitted = await admission;
  check(JSON.parse(admitted.request().postData()).analysis_record_id === seed.record,
    'actual mobile composer sends owned selected CT context');
  check(admitted.status() === 202, 'real assistant message admission queues generation');
  const request = (await admitted.json()).data.request;
  const llm = execute('docker', [...consoleArgs, 'queue:work', 'llm', '--queue=llm', '--stop-when-empty', '--sleep=1', '--tries=1']);
  await waitFor(async () => (await (await bff(user, `/ai/requests/${request.id}`)).json()).data,
    value => value.status === 'processing', 'real LLM worker processing');
  check((await bff(user, '/predictions')).status() === 200, 'CT/history API responds during real LLM queue processing');
  const ctArchive = await readFile(path.join(runtime, 'frames.zip'));
  const upload = await user.context.request.post(`${origin}/api/backend/predictions`, {
    headers: { origin, accept: 'application/json' }, multipart: {
      model_id: String(seed.model), file: { name: 'frames.zip', mimeType: 'application/zip', buffer: ctArchive },
    },
  });
  check(upload.status() === 201, 'real CT archive intake succeeds alongside LLM');
  const prediction = (await upload.json()).data;
  check(prediction.status === 'uploaded', 'real CT intake preserves explicit start');
  check((await bff(user, `/predictions/${prediction.id}/start`, 'POST', {})).status() === 200, 'real CT start queues isolated worker');
  const ct = execute('docker', [...consoleArgs, 'queue:work', 'database', '--queue=task6-ct', '--stop-when-empty', '--sleep=1', '--tries=1']);
  await Promise.all([llm, ct]);
  const reply = (await (await bff(user, `/ai/requests/${request.id}`)).json()).data;
  check(reply.status === 'completed' && reply.assistant_message.content.startsWith('Synthetic provider reply'), 'real LLM job completes through synthetic HTTP provider');
  check(reply.sources[0].id === seed.record && reply.sources[0].type === 'analysis_record', 'real job preserves owned trusted evidence separately');
  const completed = (await (await bff(user, `/predictions/${prediction.id}`)).json()).data;
  check(completed.status === 'completed', 'real CT job completes via CPU model boundary');
  await user.page.setViewportSize({ width: 390, height: 900 });
  await user.page.goto(`${origin}/workspace/assistant`);
  await user.page.getByRole('button', { name: 'Riwayat percakapan', exact: true }).click();
  await user.page.getByRole('button', { name: 'Task 6 real queued chat', exact: true }).first().click();
  await user.page.getByText(reply.assistant_message.content, { exact: true }).waitFor();
  check(true, 'actual mobile web history displays persisted reply');
  await user.page.getByText('Sumber dan metrik tepercaya', { exact: true }).click();
  check(await user.page.getByText(`Prediksi #${seed.record} · completed`, { exact: true }).isVisible(), 'actual mobile web exposes trusted CT evidence');
  await writeFile(path.join(runtime, 'provider-unavailable'), 'fixture outage');
  try {
    const offlineChat = (await (await bff(user, '/ai/conversations', 'POST', { title: 'Task 6 offline provider' })).json()).data;
    const offlineRequest = (await (await bff(user, `/ai/conversations/${offlineChat.id}/messages`, 'POST', {
      content: 'Synthetic unavailable provider', idempotency_key: `offline-${Date.now()}`,
    })).json()).data.request;
    await execute('docker', [...consoleArgs, 'queue:work', 'llm', '--queue=llm', '--stop-when-empty', '--sleep=1', '--tries=1']);
    const failed = (await (await bff(user, `/ai/requests/${offlineRequest.id}`)).json()).data;
    check(failed.status === 'failed' && failed.error_code === 'provider_unavailable' && !failed.assistant_message,
      'real queued job records unavailable provider without fabricated reply');
    check((await bff(user, '/predictions')).status() === 200, 'CT API remains available during provider outage');
  } finally { await unlink(path.join(runtime, 'provider-unavailable')); }
  const cancelledChat = (await (await bff(user, '/ai/conversations', 'POST', {})).json()).data;
  const cancellable = (await (await bff(user, `/ai/conversations/${cancelledChat.id}/messages`, 'POST', {
    content: 'Synthetic cancellation', idempotency_key: `cancel-${Date.now()}`,
  })).json()).data.request;
  const cancelled = await bff(user, `/ai/requests/${cancellable.id}/cancel`, 'POST', {});
  check(cancelled.status() === 200 && (await cancelled.json()).data.status === 'cancelled', 'real queued chat cancellation persists');
  execFileSync('docker', [...seedArgs, 'revoke-user']);
  try { check((await bff(user, '/ai/conversations')).status() === 403, 'revoked researcher account loses chat/history access immediately'); }
  finally { execFileSync('docker', [...seedArgs, 'restore-user']); }
}

try {
  const user = await login('user');
  if (mode === 'prefix' || mode === 'all') await prefix(user);
  if (mode === 'history' || mode === 'all') {
    await history(user, 'user');
    const admin = await login('admin');
    await history(admin, 'admin');
  }
  if (mode === 'flows' || mode === 'all') {
    const admin = await login('admin');
    await uploads(admin, user);
    await chatAndCt(user, admin);
  }
  console.log(`Acceptance: ${assertions} assertions passed (${mode}); real local HTTP; model/provider boundaries synthetic.`);
} finally {
  for (const context of contexts) await context.close();
  await browser.close();
}
