// Run with Node 22: node tests/prediction-download.browser.mjs
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { createRequire } from 'node:module';
import ts from 'typescript';
import { zipSync } from 'fflate';
const { chromium } = createRequire('/workspace/.browser-tools/package.json')('playwright-core');
const archive = Buffer.from(zipSync({ 'fixture.bin': randomBytes(6 * 1024 * 1024) }, {level:0}));
const digest = createHash('sha256').update(archive).digest('hex');
const requests = [];
let appOrigin;
const backend = createServer((req,res) => {
  res.setHeader('Access-Control-Allow-Origin',appOrigin);
  res.setHeader('Access-Control-Allow-Headers','ngrok-skip-browser-warning,range');
  res.setHeader('Access-Control-Expose-Headers','Content-Length,Content-Range,Accept-Ranges,X-Checksum-MD5');
  if(req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
  requests.push({url:req.url,headers:req.headers});
  if(req.headers['ngrok-skip-browser-warning'] !== 'true') {res.setHeader('Content-Type','text/html');res.end('<html>ngrok warning</html>');return;}
  if(req.url.includes('/99/')) {res.setHeader('Content-Type','text/html');res.end('<html>upstream error</html>');return;}
  if(req.url.includes('/98/')) {res.writeHead(403);res.end('denied');return;}
  res.setHeader('Content-Type','application/zip');res.setHeader('Accept-Ranges','bytes');res.setHeader('X-Checksum-MD5','fixture-digest');
  const range = req.headers.range?.match(/^bytes=(\d+)-(\d+)$/);
  const body = range ? archive.subarray(Number(range[1]),Number(range[2])+1) : archive;
  res.setHeader('Content-Length',body.length);
  if(range) {res.statusCode=206;res.setHeader('Content-Range',`bytes ${range[1]}-${range[2]}/${archive.length}`);}
  if(req.url.includes('/43/')) {
    // Delay headers so both navigations overlap, then keep both bodies active.
    setTimeout(()=>{res.flushHeaders();let offset=0;const timer=setInterval(()=>{const end=Math.min(offset+512*1024,body.length);res.write(body.subarray(offset,end));offset=end;if(offset===body.length){clearInterval(timer);res.end();}},100);res.on('close',()=>clearInterval(timer));},1000);
  } else res.end(body);
});
await new Promise(resolve=>backend.listen(0,'127.0.0.1',resolve));
const backendOrigin = `http://127.0.0.1:${backend.address().port}`;
const helper = ts.transpileModule(await fs.readFile(new URL('../src/lib/prediction-download.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.ES2020}}).outputText;
const worker = await fs.readFile(new URL('../public/prediction-download-sw.js',import.meta.url));
const app = createServer((req,res) => {
  res.setHeader('X-Frame-Options','DENY');
  res.setHeader('X-Content-Type-Options','nosniff');
  if(req.url === '/prediction-download-sw.js') {res.setHeader('Content-Type','application/javascript');res.end(worker);return;}
  if(req.url === '/helper.js') {res.setHeader('Content-Type','application/javascript');res.end(helper);return;}
  if(req.url === '/ordinary') {res.end('ordinary network response');return;}
  const match = req.url.match(/^\/api\/backend\/predictions\/(\d+)\/download\/(results|complete)\?prepare=1$/);
  if(match) {
    res.setHeader('Content-Type','application/json');res.end(JSON.stringify({success:true,data:{url:`${backendOrigin}/prefix/api/downloads/predictions/${match[1]}/${match[2]}?expires=${Math.floor(Date.now()/1000)+300}&owner=7&signature=${'a'.repeat(64)}`,filename:`${match[2]}_${match[1]}.zip`}}));return;
  }
  res.setHeader('Content-Type','text/html');res.end(`<button id="results">Results</button><button id="complete">Complete</button><button id="html">HTML error</button><button id="denied">Denied</button><span role="status" aria-live="polite"></span><script type="module">import {startPredictionDownload} from '/helper.js';window.startPredictionDownload=startPredictionDownload;for(const [name,id,kind] of [['results',42,'results'],['complete',42,'complete'],['html',99,'results'],['denied',98,'results']]){document.getElementById(name).onclick=async(event)=>{const b=event.target;b.disabled=true;document.querySelector('[role=status]').textContent='';try{await startPredictionDownload('/api/backend/predictions/'+id+'/download/'+kind);}catch(e){document.querySelector('[role=status]').textContent=e.message;}finally{b.disabled=false;}}}</script>`);
});
await new Promise(resolve=>app.listen(0,'127.0.0.1',resolve));
appOrigin = `http://127.0.0.1:${app.address().port}`;
const profile = await fs.mkdtemp(path.join(os.tmpdir(),'prediction-download-profile-'));
let context;
try {
  context = await chromium.launchPersistentContext(profile,{executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox'],acceptDownloads:true});
  const page = await context.newPage();await page.goto(appOrigin+'/dashboard');await page.waitForFunction(()=>!!window.startPredictionDownload);
  await page.evaluate(()=>{URL.createObjectURL=()=>{throw Error('Blob buffering forbidden');};});
  const files=[];
  for(const kind of ['results','complete']) {
    const pending=page.waitForEvent('download');await page.locator('#'+kind).click();const download=await pending;
    assert.equal(download.suggestedFilename(),`${kind}_42.zip`);const file=await download.path();
    assert.equal(createHash('sha256').update(await fs.readFile(file)).digest('hex'),digest);assert.equal(page.url(),appOrigin+'/dashboard');
    files.push({kind,bytes:archive.length,sha256:digest});
    await page.waitForFunction(id=>!document.getElementById(id).disabled,kind);
  }
  const overlapping=[];
  let timeout;
  const bothDownloads=new Promise((resolve,reject)=>{
    timeout=setTimeout(()=>reject(Error('Expected two overlapping browser downloads; observed '+overlapping.map(file=>file.suggestedFilename()).join(','))),7000);
    page.on('download',download=>{overlapping.push(download);if(overlapping.length===2){clearTimeout(timeout);resolve();}});
  });
  await page.evaluate(async()=>Promise.all(['results','complete'].map(kind=>window.startPredictionDownload('/api/backend/predictions/43/download/'+kind))));
  await bothDownloads;
  const activeTargets=await page.locator('iframe[title="Prediction archive download"]').count();
  assert.equal(activeTargets,2,'independent targets stay alive while both delayed streams are active');
  for(const download of overlapping){assert.ok(['results_43.zip','complete_43.zip'].includes(download.suggestedFilename()));const file=await download.path();assert.equal(createHash('sha256').update(await fs.readFile(file)).digest('hex'),digest);}
  assert.deepEqual(overlapping.map(file=>file.suggestedFilename()).sort(),['complete_43.zip','results_43.zip']);
  assert.equal(page.url(),appOrigin+'/dashboard');
  await page.waitForFunction(()=>document.querySelectorAll('iframe[title="Prediction archive download"]').length===0);
  assert.equal(await page.evaluate(async()=>await(await fetch('/ordinary')).text()),'ordinary network response');
  const range = await page.evaluate(async ({backendOrigin})=>{
    const registration=await navigator.serviceWorker.ready;const channel=new MessageChannel();
    return await new Promise((resolve,reject)=>{channel.port1.onmessage=async({data})=>{if(data.type!=='registered')return;try{const response=await fetch(data.path,{headers:{Range:'bytes=0-127'}});resolve({status:response.status,range:response.headers.get('content-range'),bytes:(await response.arrayBuffer()).byteLength,digest:response.headers.get('x-checksum-md5')});}catch(e){reject(e);}finally{channel.port1.close();}};registration.active.postMessage({type:'REGISTER_PREDICTION_DOWNLOAD',url:backendOrigin+'/prefix/api/downloads/predictions/42/results?expires='+Math.floor(Date.now()/1000+300)+'&owner=7&signature='+'a'.repeat(64),filename:'results_42.zip'},[channel.port2]);});
  },{backendOrigin});
  assert.deepEqual(range,{status:206,range:`bytes 0-127/${archive.length}`,bytes:128,digest:'fixture-digest'});
  for(const id of ['html','denied']) {await page.locator('#'+id).click();await page.waitForFunction(()=>document.querySelector('[role=status]').textContent.includes('Unable to download'));assert.equal(page.url(),appOrigin+'/dashboard');}
  assert.ok(requests.length>=5);for(const request of requests){assert.equal(request.headers['ngrok-skip-browser-warning'],'true');assert.equal(request.headers.authorization,undefined);assert.equal(request.headers.cookie,undefined);}
  console.log(JSON.stringify({passed:true,freshProfile:true,pageUnchanged:true,noBlobBuffering:true,files,overlapping:overlapping.map(file=>({filename:file.suggestedFilename(),bytes:archive.length,sha256:digest})),activeTargetsDuringStreams:activeTargets,targetsAfterStreams:0,range,backendRequests:requests.length},null,2));
} finally {await context?.close();await fs.rm(profile,{recursive:true,force:true});await new Promise(resolve=>app.close(resolve));await new Promise(resolve=>backend.close(resolve));}
