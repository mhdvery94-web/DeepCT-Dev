import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import vm from 'node:vm';
import { buildPredictionDownload, startPredictionDownload } from '../src/lib/prediction-download.ts';

const signed = (kind = 'results') => `/api/downloads/predictions/42/${kind}?expires=${Math.floor(Date.now() / 1000) + 600}&owner=7&signature=${'a'.repeat(64)}`;
test('prepare preserves deployment prefix and exact signed query with safe filename', () => {
  const path = signed();
  assert.deepEqual(buildPredictionDownload('https://api.example/deepct/api/', path, '42', 'results'), { url: `https://api.example/deepct${path}`, filename: 'results_42.zip' });
  for (const path of ['https://evil.test' + signed(), '//evil.test' + signed(), signed('complete'), signed().replace('/42/', '/43/'), signed() + '&ngrok-skip-browser-warning=true', signed().replace('/api/', '/api/../api/')]) {
    assert.throws(() => buildPredictionDownload('https://api.example/api', path, '42', 'results'));
  }
});
test('client reports unsupported worker and malformed path instead of navigating', async () => {
  await assert.rejects(startPredictionDownload('/api/backend/predictions/42/download/results'), /browser|worker/i);
  await assert.rejects(startPredictionDownload('https://evil.test'), /path/i);
});
async function worker(options = {}) {
  const listeners = {};
  const clients = new Map([['window', { type: 'window', url: 'https://app.test/dashboard' }], ['foreign', { type: 'window', url: 'https://evil.test/' }]]);
  const requests = [];
  const context = vm.createContext({ URL, Headers, Request, Response, ReadableStream, AbortController, crypto: globalThis.crypto, Date: options.Date ?? Date, Map, Set,
    self: { location: { origin: 'https://app.test' }, clients: { get: async id => clients.get(id), claim: async () => {} }, skipWaiting: async () => {}, addEventListener: (type, fn) => { listeners[type] = fn; } },
    fetch: async (url, init) => { requests.push({url, init}); return options.response?.(url, init) ?? new Response(new Uint8Array([80,75,3,4]), { headers: { 'content-type': 'application/zip', 'content-length': '4', 'content-range': 'bytes 0-3/4', 'accept-ranges': 'bytes', 'x-checksum-md5': 'digest' }, status: 206 }); }
  });
  vm.runInContext(await fs.readFile(new URL('../public/prediction-download-sw.js', import.meta.url), 'utf8'), context);
  async function register(data = {}, source = 'window') {
    let promise; const messages = [];
    const port = {postMessage:x=>messages.push(x)};
    messages.cancel=()=>port.onmessage({data:{type:"cancel"}});
    listeners.message({ data: { type: 'REGISTER_PREDICTION_DOWNLOAD', url: 'https://api.test/prefix' + signed(), filename: 'results_42.zip', ...data }, source: { id: source }, ports: [port], waitUntil: p => { promise = p; } });
    await promise;
    return messages;
  }
  async function download(path, headers = {}) {
    let response;
    listeners.fetch({ request: new Request('https://app.test' + path, { headers }), respondWith: p => { response = p; } });
    return response && await response;
  }
  return { register, download, requests };
}
test('worker validates window source, signed target, filename and narrow interception scope', async () => {
  const w = await worker();
  for (const data of [{ url: 'https://evil.test/anything' }, { url: 'javascript:alert(1)' }, { url: 'https://api.test' + signed() + '&extra=1' }, { filename: '../results_42.zip' }, { filename: 'complete_42.zip' }, { url: 'https://user:pass@api.test' + signed() }]) assert.equal((await w.register(data))[0].type, 'error');
  assert.equal((await w.register({}, 'foreign'))[0].type, 'error');
  assert.equal(await w.download('/api/backend/predictions'), undefined);
  assert.equal(await w.download('/__prediction-download/other/extra'), undefined);
});
test('worker streams with bypass header, no credentials/auth, strict redirect, and Range 206 headers', async () => {
  const w = await worker(); const messages = await w.register();
  assert.equal(messages[0].type, 'registered');
  const response = await w.download(messages[0].path, { range: 'bytes=0-3' });
  assert.equal(response.status, 206);
  for (const [name, value] of [['content-type','application/zip'], ['content-range','bytes 0-3/4'], ['accept-ranges','bytes'], ['x-checksum-md5','digest'], ['content-length','4'], ['content-disposition','attachment; filename="results_42.zip"']]) assert.equal(response.headers.get(name), value);
  assert.deepEqual([...new Uint8Array(await response.arrayBuffer())], [80,75,3,4]);
  assert.equal(w.requests[0].init.headers.get('ngrok-skip-browser-warning'), 'true');
  assert.equal(w.requests[0].init.headers.get('range'), 'bytes=0-3');
  assert.equal(w.requests[0].init.headers.has('authorization'), false);
  assert.equal(w.requests[0].init.credentials, 'omit'); assert.equal(w.requests[0].init.redirect, 'error');
  assert.equal((await w.download(messages[0].path)).status, 206, 'range retries retain capability');
  assert.equal(messages[1].type, 'started');
});
test('worker rejects HTML and upstream errors and sends client error', async () => {
  for (const response of [() => new Response('<html>warning</html>', {headers:{'content-type':'text/html'}}), () => new Response('denied', {status:403}), () => {throw Error('network failure');}]) {
    const w = await worker({ response }); const messages = await w.register();
    assert.equal((await w.download(messages[0].path)).status, 0);
    assert.equal(messages[1].type, 'error');
  }
});
test('worker expires records, bounds map, and never buffers archive body', async () => {
  let now = Date.now(); class Clock extends Date { static now() { return now; } }
  const w = await worker({ Date: Clock }); const first = (await w.register())[0];
  for(let i=0;i<32;i++) await w.register();
  assert.equal((await w.download(first.path)).status, 0);
  const last = (await w.register())[0]; now += 601_000;
  assert.equal((await w.download(last.path)).status, 0);
  const code = await fs.readFile(new URL('../public/prediction-download-sw.js', import.meta.url), 'utf8');
  assert.doesNotMatch(code, /\.(blob|arrayBuffer|text)\s*\(/);
});

test('client shares worker startup across concurrent downloads and handles channel/backend errors', async () => {
  const saved = Object.fromEntries(['navigator','fetch','document','setTimeout'].map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)]));
  let registrations = 0; let clicks = 0; const ports = [];let autoStart=true;let cancellations=0;
  const active = { state: 'activated', postMessage(data, transfer) { const port = transfer[0]; ports.push(port);port.onmessage=({data})=>{if(data?.type==='cancel'){cancellations++;port.postMessage({type:'error',message:'cancelled'});}}; port.postMessage(data.url === 'bad' ? {type:'error',message:'Rejected target'} : {type:'registered',path:'/__prediction-download/' + ports.length.toString(16).padStart(64,'0')}); } };
  const changes = new Set();
  const serviceWorker = {controller:null,register:async () => {registrations++;setTimeout(()=>{assert.equal(clicks,0,'must await page control before anchor click');serviceWorker.controller=active;for(const changed of changes)changed();},10);return {active};},ready:Promise.resolve(),addEventListener:(_,listener)=>changes.add(listener),removeEventListener:(_,listener)=>changes.delete(listener)};
  Object.defineProperty(globalThis, 'navigator', {configurable:true,value:{serviceWorker}});
  const frames=[];const targets=[];
  globalThis.document = {body:{append(){}},createElement:tag=>{const element={removed:false,click(){clicks++;targets.push(this.target);if(autoStart)setTimeout(()=>ports.forEach(port=>port.postMessage({type:'started'})),0);},remove(){this.removed=true;}};if(tag==='iframe')frames.push(element);return element;}};
  globalThis.fetch = async () => Response.json({success:true,data:{url:'https://api.test'+signed(),filename:'results_42.zip'}});
  try {
    await Promise.all([startPredictionDownload('/api/backend/predictions/42/download/results'),startPredictionDownload('/api/backend/predictions/42/download/results')]);
    assert.equal(registrations,1); assert.equal(clicks,2);
    assert.equal(new Set(targets).size,2,'each concurrent navigation has its own target');
    assert.equal(frames.filter(frame=>!frame.removed).length,2,'started streams keep both targets');
    ports.forEach(port=>port.postMessage({type:'complete'}));await new Promise(resolve=>setTimeout(resolve,10));
    assert.equal(frames.filter(frame=>!frame.removed).length,0,'source completion removes targets');
    await Promise.all(Array.from({length:32},()=>startPredictionDownload('/api/backend/predictions/42/download/results')));
    await assert.rejects(startPredictionDownload('/api/backend/predictions/42/download/results'),/Too many active downloads/);
    ports.forEach(port=>port.postMessage({type:'complete'}));await new Promise(resolve=>setTimeout(resolve,10));
    assert.equal(frames.filter(frame=>!frame.removed).length,0);
    globalThis.fetch = async () => Response.json({success:true,data:{url:'bad',filename:'results_42.zip'}});
    await assert.rejects(startPredictionDownload('/api/backend/predictions/42/download/results'), /Rejected target/);
    globalThis.fetch = async () => Response.json({success:false,message:'Not owned'}, {status:403});
    await assert.rejects(startPredictionDownload('/api/backend/predictions/42/download/results'), /Not owned/);
    globalThis.fetch = async () => Response.json({success:true,data:{url:'https://api.test',filename:'../evil.zip'}});
    await assert.rejects(startPredictionDownload('/api/backend/predictions/42/download/results'), /Invalid download response/);
    autoStart=false;
    globalThis.fetch=async()=>Response.json({success:true,data:{url:'https://api.test'+signed(),filename:'results_42.zip'}});
    const realSetTimeout=globalThis.setTimeout;let headerDeadlines=0;
    globalThis.setTimeout=(callback,delay,...args)=>{if(delay===5*60_000){headerDeadlines++;return realSetTimeout(callback,20,...args);}return realSetTimeout(callback,delay,...args);};
    await assert.rejects(startPredictionDownload('/api/backend/predictions/42/download/results'),/took too long/);
    await new Promise(resolve=>realSetTimeout(resolve,10));
    assert.equal(headerDeadlines,1,'archive-header wait has a separate five-minute deadline');assert.equal(cancellations,1);
    assert.equal(frames.filter(frame=>!frame.removed).length,0,'cancel acknowledgment cleans timed-out preparation');
  } finally { for(const [key, descriptor] of Object.entries(saved)) { if(descriptor) Object.defineProperty(globalThis,key,descriptor); else delete globalThis[key]; } for(const port of ports) port.close(); }
});

test('BFF prepare stays small, authenticated, preserves raw signature and retains default 307', async () => {
  const { default: ts } = await import('typescript');
  const source = await fs.readFile(new URL('../src/app/api/backend/[...path]/route.ts',import.meta.url),'utf8');
  const code = ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
  const exports = {}; const requests=[]; let target=signed(); let status=200;
  const require = name => ({'next/headers':{cookies:async()=>({get:()=>({value:'test-private-token'})})},'next/server':{NextResponse:{json:Response.json,redirect:(url,status)=>new Response(null,{status,headers:{location:url}})}},'@/lib/api':{apiUrl:path=>'https://api.test/prefix/api'+path},'@/lib/auth-constants':{AUTH_COOKIE_NAME:'test-cookie'},'@/lib/request-security':{hasTrustedOrigin:()=>true},'@/lib/prediction-download':{buildPredictionDownload}}[name]);
  vm.runInNewContext(code,{exports,require,Headers,Response,URL,Set,fetch:async(url,init)=>{requests.push({url,init});return Response.json(status===200?{success:true,data:{path:target}}:{success:false,message:'Not owned'},{status});}});
  const request = query=>({method:'GET',headers:new Headers(),nextUrl:new URL('https://app.test/api/backend/predictions/42/download/results'+query)});
  const context={params:Promise.resolve({path:['predictions','42','download','results']})};
  const prepared=await exports.GET(request('?prepare=1'),context);
  assert.equal(prepared.status,200);assert.equal(prepared.headers.get('cache-control'),'no-store');
  assert.deepEqual(await prepared.json(),{success:true,data:{url:'https://api.test/prefix'+target,filename:'results_42.zip'}});
  assert.equal(requests[0].url,'https://api.test/prefix/api/predictions/42/download-link?kind=results');assert.equal(requests[0].init.headers.get('authorization'),'Bearer test-private-token');
  const redirect=await exports.GET(request(''),context);assert.equal(redirect.status,307);assert.equal(redirect.headers.get('location'),'https://api.test/prefix'+target);
  target=signed('complete');assert.equal((await exports.GET(request('?prepare=1'),context)).status,502);
  status=403;assert.equal((await exports.GET(request('?prepare=1'),context)).status,403);
});

test('worker returns the upstream stream before archive completion', async () => {
  let complete;
  const stream = new ReadableStream({start(controller){controller.enqueue(new Uint8Array([80,75,3,4]));complete=()=>controller.close();}});
  const w = await worker({response:()=>new Response(stream,{headers:{'content-type':'application/zip'}})});
  const messages = await w.register();
  const response = await Promise.race([w.download(messages[0].path),new Promise((_,reject)=>setTimeout(()=>reject(Error('buffered entire stream')),1000))]);
  const reader=response.body.getReader();assert.deepEqual([...((await reader.read()).value)],[80,75,3,4]);assert.equal(messages.some(message=>message.type==='complete'),false);complete();assert.equal((await reader.read()).done,true);assert.equal(messages.at(-1).type,'complete');
});

test('worker propagates explicit preparation cancellation to the upstream fetch', async () => {
  let initiated;
  const pending=new Promise(resolve=>{initiated=resolve;});
  const w=await worker({response:(_url,init)=>new Promise((_,reject)=>{initiated(init.signal);init.signal.addEventListener('abort',()=>reject(Error('cancelled')));})});
  const messages=await w.register();const response=w.download(messages[0].path);const signal=await pending;
  assert.equal(signal.aborted,false);messages.cancel();
  assert.equal((await response).status,0);assert.equal(signal.aborted,true);assert.equal(messages.at(-1).type,'error');
});

test('worker closes target lifecycle on stream errors/cancellation, and waits for simultaneous range streams', async () => {
  let source;
  const w=await worker({response:()=>new Response(new ReadableStream({start(controller){source=controller;}}),{headers:{'content-type':'application/zip'}})});
  const messages=await w.register();const response=await w.download(messages[0].path);const reader=response.body.getReader();
  source.error(Error('connection lost'));await assert.rejects(reader.read(),/connection lost/);assert.equal(messages.at(-1).type,'error');
  const cancellation=await w.register();const cancelled=await w.download(cancellation[0].path);await cancelled.body.cancel();
  assert.equal(w.requests.at(-1).init.signal.aborted,true);assert.equal(cancellation.at(-1).type,'complete');
  const retry=await w.download(cancellation[0].path);assert.equal(retry.status,200);assert.equal(w.requests.at(-1).init.signal.aborted,false,'cancelling one stream does not poison range retries');await retry.body.cancel();
  const concurrent=await w.register();const first=await w.download(concurrent[0].path);const firstSource=source;const second=await w.download(concurrent[0].path);const secondSource=source;
  firstSource.close();assert.equal((await first.body.getReader().read()).done,true);assert.equal(concurrent.some(message=>message.type==='complete'),false);
  secondSource.close();assert.equal((await second.body.getReader().read()).done,true);assert.equal(concurrent.at(-1).type,'complete');
});
