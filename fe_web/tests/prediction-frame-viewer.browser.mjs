// Mounts the actual client component and its helpers with React; no Next server or remote data.
// Run from fe_web with Node 22: node tests/prediction-frame-viewer.browser.mjs
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import ts from 'typescript';
const require = createRequire(import.meta.url);
const { chromium } = createRequire('/workspace/.browser-tools/package.json')('playwright-core');
const modules = {};
for (const name of ['react', 'react-dom', 'react-dom/client', 'react/jsx-runtime', 'scheduler']) {
  const filenames = { 'react-dom/client': 'react-dom-client', 'react/jsx-runtime': 'react-jsx-runtime' };
  const packageName = name.split('/')[0];
  const base = new URL('./', 'file://' + require.resolve(packageName + '/package.json'));
  modules[name] = await fs.readFile(new URL(`cjs/${filenames[name] ?? name}.production.js`, base), 'utf8');
}
for (const [name, file] of Object.entries({
  '@/lib/client-api': '../src/lib/client-api.ts',
  '@/lib/prediction-frames': '../src/lib/prediction-frames.ts',
  viewer: '../src/components/prediction-frame-viewer.tsx',
})) {
  try { modules[name] = ts.transpileModule(await fs.readFile(new URL(file, import.meta.url), 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX },
  }).outputText; } catch (error) { if (error.code !== 'ENOENT') throw error; }
}
const bundle = `const modules={${Object.entries(modules).map(([name, code]) => `${JSON.stringify(name)}:function(module,exports,require){${code}\n}`).join(',')}};const cache={};function require(name){if(!cache[name]){const module={exports:{}};cache[name]=module;modules[name](module,module.exports,require);}return cache[name].exports;}const React=require('react');const root=require('react-dom/client').createRoot(document.getElementById('root'));window.showPrediction=(id,completed=true)=>root.render(React.createElement(require('viewer').PredictionFrameViewer,{predictionId:id,completed}));window.showPrediction(42);`;
const css = (await fs.readFile(new URL('../src/app/globals.css', import.meta.url), 'utf8')).replace('@import "tailwindcss";', '');
const frames = [{ name: 'frame10.tif', kind: 'output', size: 100 }, { name: 'frame2.tif', kind: 'output', size: 100 }, { name: 'frame2.tif', kind: 'input', size: 100 }, { name: 'frame1.tif', kind: 'input', size: 100 }, ...Array.from({ length: 12 }, (_, index) => ({ name: `frame${index + 11}.tif`, kind: index % 2 ? 'input' : 'output', size: 100 })), { name: 'frame0.tif', kind: 'unknown' }, null, { name: '../frame3.tif', kind: 'output' }];
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64');
const requests = [];
let deniedOnce = false;
const app = createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/bundle.js') { res.setHeader('Content-Type', 'application/javascript; charset=utf-8'); res.end(bundle); return; }
  if (url.pathname === '/style.css') { res.setHeader('Content-Type', 'text/css; charset=utf-8'); res.end(css); return; }
  if (url.pathname.endsWith('/preview')) {
    requests.push(req.url);
    if (url.pathname.includes('/47/')) { res.writeHead(422); res.end(); return; }
    res.setHeader('Content-Type', 'image/png'); res.end(png); return;
  }
  if (url.pathname.endsWith('/frames')) {
    res.setHeader('Content-Type', 'application/json');
    const id = Number(url.pathname.split('/')[4]);
    const send = () => {
      if (id === 46 && !deniedOnce) { deniedOnce = true; res.writeHead(403); res.end(JSON.stringify({ success: false, message: 'Fixture access denied' })); return; }
      res.end(JSON.stringify({ success: true, data: id === 45 ? [] : frames }));
    };
    if (id === 43) setTimeout(send, 600); else send();
    return;
  }
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/style.css"><main style="padding:24px;max-width:1100px;margin:auto;min-width:0"><div id="root"></div></main><script src="/bundle.js"></script></html>');
});
await new Promise(resolve => app.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${app.address().port}`;
let browser;
try {
  browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto(origin + '/dashboard');
  const combined = page.getByRole('button', { name: /^All frames/ });
  await combined.waitFor({ timeout: 5000 });
  assert.equal(await combined.getAttribute('aria-pressed'), 'true');
  const stage = page.locator('.frame-stage');
  const badge = stage.locator('.frame-kind-badge');
  const thumbnailButtons = page.locator('.frame-thumbnails button');
  const expectFrame = async (name, kind) => {
    await page.waitForFunction(({ name, kind }) => {
      const img = document.querySelector('.frame-stage img');
      return img?.alt === `${kind === 'input' ? 'Input' : 'AI'} · ${name}` && new URL(img.src).searchParams.get('kind') === kind && img.complete && img.naturalWidth > 0;
    }, { name, kind }, { timeout: 5000 }).catch(async error => {
      throw new Error(error.message + '\n' + JSON.stringify(await page.evaluate(() => ({ html: document.getElementById('root').innerHTML, image: Array.from(document.images, img => ({ src: img.src, complete: img.complete, naturalWidth: img.naturalWidth })) }))));
    });
    assert.equal(await badge.textContent(), kind === 'input' ? 'Input' : 'AI');
    assert.ok((await stage.locator('img').getAttribute('src')).includes('/' + encodeURIComponent(name) + '/preview?kind=' + kind));
  };
  await expectFrame('frame1.tif', 'input');
  assert.equal(await thumbnailButtons.count(), 12);
  const initialThumbnailRequests = requests.filter(url => new URL(url, origin).searchParams.get('size') === '128');
  assert.ok(initialThumbnailRequests.length > 0 && initialThumbnailRequests.length <= 12);
  const firstPage = new Set(await thumbnailButtons.locator('img').evaluateAll(images => images.map(img => new URL(img.src).pathname + new URL(img.src).search)));
  assert.ok(initialThumbnailRequests.every(url => firstPage.has(url)), 'only current-page thumbnails requested');
  assert.deepEqual(await thumbnailButtons.locator('.frame-kind-badge').allTextContents(), ['Input', 'Input', 'AI', 'AI', 'AI', 'Input', 'AI', 'Input', 'AI', 'Input', 'AI', 'Input']);
  await page.getByRole('button', { name: 'Next frame', exact: true }).click(); await expectFrame('frame2.tif', 'input');
  await page.getByRole('button', { name: 'Next frame', exact: true }).click(); await expectFrame('frame2.tif', 'output');
  await thumbnailButtons.nth(3).click(); await expectFrame('frame10.tif', 'output');
  await page.getByRole('button', { name: /^Input frames/ }).click(); await expectFrame('frame1.tif', 'input');
  assert.deepEqual([...new Set(await thumbnailButtons.locator('.frame-kind-badge').allTextContents())], ['Input']);
  assert.equal(await thumbnailButtons.count(), 8);
  await page.getByRole('button', { name: /^AI frames/ }).click(); await expectFrame('frame2.tif', 'output');
  assert.deepEqual([...new Set(await thumbnailButtons.locator('.frame-kind-badge').allTextContents())], ['AI']);
  assert.equal(await thumbnailButtons.count(), 8);
  await page.getByRole('button', { name: 'Play preview', exact: true }).click(); await expectFrame('frame10.tif', 'output');
  await page.getByRole('button', { name: 'Pause preview', exact: true }).click();
  await combined.click(); await expectFrame('frame1.tif', 'input');
  const range = page.getByRole('slider', { name: 'Choose frame' });
  await range.fill('12'); await expectFrame('frame19.tif', 'output');
  assert.equal(await thumbnailButtons.count(), 4);
  await page.getByRole('button', { name: 'Previous frame', exact: true }).click(); await expectFrame('frame18.tif', 'input');
  assert.equal(await thumbnailButtons.count(), 12);
  const widths = [];
  for (const width of [1366, 768, 390]) {
    await page.setViewportSize({ width, height: 900 });
    await page.getByRole('button', { name: 'Next frame', exact: true }).click(); await expectFrame('frame19.tif', 'output');
    const dimensions = await page.evaluate(() => ({ viewport: innerWidth, document: document.documentElement.scrollWidth, section: document.querySelector('section').getBoundingClientRect().width }));
    assert.ok(dimensions.document <= dimensions.viewport, JSON.stringify(dimensions));
    assert.ok(await badge.isVisible()); widths.push(dimensions);
    await page.screenshot({ path: `/tmp/deepct-task6-${width}.png`, fullPage: true });
    await page.getByRole('button', { name: 'Previous frame', exact: true }).click();
  }
  await page.evaluate(() => window.showPrediction(43));
  await page.getByRole('status').filter({ hasText: 'Rendering' }).waitFor();
  assert.equal(await stage.count(), 0, 'old prediction must disappear during load');
  await page.evaluate(() => window.showPrediction(44, false)); await expectFrame('frame1.tif', 'input');
  await page.waitForTimeout(700);
  assert.equal(await combined.count(), 0, 'stale completed request cannot restore combined');
  assert.equal(await page.getByRole('button', { name: /^AI frames/ }).count(), 0);
  await page.evaluate(() => window.showPrediction(45));
  await page.getByRole('status').filter({ hasText: 'No frames' }).waitFor(); assert.equal(await stage.count(), 0);
  await page.evaluate(() => window.showPrediction(46));
  await page.getByRole('alert').filter({ hasText: 'Fixture access denied' }).waitFor();
  assert.equal(await stage.count(), 0);
  await page.getByRole('button', { name: 'Retry preview' }).click();
  await expectFrame('frame1.tif', 'input'); assert.equal(await page.getByRole('alert').count(), 0);
  await page.evaluate(() => window.showPrediction(47));
  await page.getByRole('alert').filter({ hasText: 'This frame could not be rendered' }).waitFor();
  await page.getByRole('button', { name: /^AI frames/ }).click();
  await page.getByRole('alert').filter({ hasText: 'This frame could not be rendered' }).waitFor();
  await page.evaluate(() => window.showPrediction(48)); await expectFrame('frame1.tif', 'input');
  assert.equal(await page.getByRole('alert').count(), 0);
  assert.equal(page.url(), origin + '/dashboard');
  assert.deepEqual(errors, []);
  assert.ok(requests.some(url => url.includes('/frame2.tif/preview?kind=input')));
  assert.ok(requests.some(url => url.includes('/frame2.tif/preview?kind=output')));
  assert.ok(requests.every(url => ['input', 'output'].includes(new URL(url, origin).searchParams.get('kind'))));
  console.log(JSON.stringify({ passed: true, actualComponent: true, validatedFrames: 16, firstPageThumbnails: 12, initialThumbnailRequests: initialThumbnailRequests.length, secondPageThumbnails: 4, widths, pageUnchanged: true, staleRequestIgnored: true, uploadedDefaultInput: true, emptyErrorRetryImageRecovery: true, kindSpecificRequests: requests.length }, null, 2));
} finally { await browser?.close(); await new Promise(resolve => app.close(resolve)); }
