// Real Chromium component behavior through the authenticated Next BFF.
// Run with Node 22 from fe_web. No provider or production API is contacted.
import assert from 'node:assert/strict';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import { chromium } from '/workspace/.browser-tools/node_modules/playwright-core/index.mjs';

let enabled = false, state = 'completed', failSend = false, failPoll = false, refuseSend = false;
let originalContextId = null, mode;
let failAnalyses = false, emptyAnalyses = false;
const analysisCalls = [];
let analysisGate;
const sends = [];
const date = '2026-10-10T12:00:00Z';
const msg = (id, role, content) => ({ id, role, content, created_at: date });
const request = () => ({ id: 42, conversation_id: 7, user_message_id: 100, analysis_record_id: originalContextId, status: state, model: 'deepseek-r1:1.5b', prompt_version: 'deepct-assistant-v1', experimental: true, error_code: state === 'failed' ? 'provider_timeout' : null, assistant_message: state === 'completed' ? msg(101, 'assistant', 'Jawaban eksperimen') : null, sources: state === 'completed' ? [{type:'analysis_record',id:3,status:'pending',input_files_count:2,output_files_count:null,processing_time_seconds:null,expired:false,files_deleted:false,model:null,metrics:{mae:null,ssim:0},validation_provenance:{},frame_provenance:[]}] : [], metrics: state === 'completed' ? {total_duration:50000000000} : null, created_at:date, started_at:null, finished_at:null });
const fixture = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1');
  const path = url.pathname.replace(/^\/api/, '');
  const page = Number(url.searchParams.get('page') || 1);
  let payload, status = 200;
  if (path === '/user') payload = {id:1,name:'Researcher Test',email:'fixture@example.test',role:req.headers.authorization === 'Bearer fake-admin' ? 'admin' : 'user',must_change_password:false};
  else if (path === '/ai/status') payload = {mode,enabled,model:'deepseek-r1:1.5b',prompt_version:'deepct-assistant-v1',experimental:true,limits:{message_characters:2000,requests_per_day:20,queue:10}};
  else if (path === '/predictions') {
    analysisCalls.push(url.pathname + url.search);
    if (analysisGate) await analysisGate;
    if (failAnalyses) {status=502;payload={success:false,message:'Daftar analisis terputus'};}
    else {
      res.writeHead(200, {'Content-Type':'application/json'});
      res.end(JSON.stringify({success:true,data:emptyAnalyses?[]:[{id:3,status:'completed',expired:true,files_deleted:true},...(page===2?[{id:24,status:'failed'}]:[])],pagination:{current_page:page,last_page:emptyAnalyses?1:2,per_page:20,total:emptyAnalyses?0:21}}));return;
    }
  }
  else if (path === '/ai/conversations' && req.method === 'GET') payload = {conversations:[{id:page === 1 ? 7 : 8,title:page === 1 ? 'Riwayat riset' : 'Percakapan lama',created_at:date,updated_at:date}],pagination:{current_page:page,last_page:2,per_page:20,total:21}};
  else if (path === '/ai/conversations' && req.method === 'POST') payload = {id:7,title:'Percakapan baru',created_at:date,updated_at:date};
  else if (/^\/ai\/conversations\/\d+$/.test(path)) payload = {id:7,title:'Riwayat riset',messages:[msg(page === 1 ? 100 : 90,'user',page === 1 ? 'Pertanyaan tersimpan' : 'Pesan lama'),...(state === 'completed' && page === 1 ? [msg(101,'assistant','Jawaban eksperimen')] : [])],pagination:{current_page:page,last_page:2,per_page:20,total:21},request:request()};
  else if (path.endsWith('/messages')) {
    let text = ''; for await (const chunk of req) text += chunk;
    const body = JSON.parse(text); sends.push(body);
    if (refuseSend) {refuseSend=false;status=404;payload={success:false,message:'Konteks tidak ditemukan'};}
    else if (failSend) {failSend=false;status=502;payload={success:false,message:'Jaringan terputus'};}
    else {state='queued';originalContextId=body.analysis_record_id ?? null;payload={request:request(),user_message:msg(100,'user',body.content)};status=202;}
  } else if (path.endsWith('/cancel')) {state='cancelled';payload=request();}
  else if (path.startsWith('/ai/requests/')) {
    if (failPoll) {status=502;payload={success:false,message:'Jaringan polling terputus'};}
    else payload=request();
  } else {status=404;payload={success:false,message:'Fixture endpoint missing: '+path};}
  res.writeHead(status, {'Content-Type':'application/json'});res.end(JSON.stringify(payload?.success === false ? payload : {success:true,data:payload}));
});
await new Promise(resolve => fixture.listen(8213,'127.0.0.1',resolve));
const app = spawn(process.execPath,['node_modules/next/dist/bin/next','dev','--hostname','127.0.0.1','--port','3213'],{env:{...process.env,LARAVEL_API_BASE_URL:'http://127.0.0.1:8213/api'},stdio:['ignore','pipe','pipe']});
let log = '';app.stdout.on('data',c=>{log+=c;});app.stderr.on('data',c=>{log+=c;});
let browser;
try {
  for(let i=0;i<120;i++){if(log.includes('Ready in')) break;if(app.exitCode !== null) throw Error(log);await new Promise(r=>setTimeout(r,250));}
  browser = await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
  const context = await browser.newContext({viewport:{width:1440,height:1000},reducedMotion:'reduce'});
  await context.grantPermissions(['clipboard-read','clipboard-write']);
  await context.addCookies([{name:'deepct_session',value:'fake-user',url:'http://127.0.0.1:3213',httpOnly:true}]);
  const page = await context.newPage();
  mode='metadata'; enabled=true;
  for (const token of ['fake-user','fake-admin']) {
    await context.addCookies([{name:'deepct_session',value:token,url:'http://127.0.0.1:3213',httpOnly:true}]);
    await page.goto('http://127.0.0.1:3213/workspace/assistant?analysis_record_id=99');
    const picker=page.getByRole('combobox',{name:'Pilih analisis',exact:true});
    await picker.waitFor({timeout:20000});
    await page.getByRole('option',{name:'Analisis #3 · completed',exact:true}).waitFor({state:'attached'});
    assert.equal(await picker.inputValue(),'99');
    assert.equal(analysisCalls.at(-1),'/api/predictions?page=1&per_page=20');
    failAnalyses=true;
    await page.getByRole('button',{name:'Muat analisis lainnya',exact:true}).click();
    await page.getByText('Daftar analisis terputus',{exact:true}).waitFor();
    assert.equal(await picker.inputValue(),'99');
    failAnalyses=false;
    await page.getByRole('button',{name:'Coba muat analisis lagi',exact:true}).click();
    await page.getByRole('option',{name:'Analisis #24 · failed',exact:true}).waitFor({state:'attached'});
    assert.equal(analysisCalls.at(-1),'/api/predictions?page=2&per_page=20');
    assert.equal(await picker.getByRole('option',{name:'Analisis #3 · completed',exact:true}).count(),1);
    await picker.selectOption('24');
    await page.getByRole('button',{name:'+ Chat baru',exact:true}).click();
    assert.equal(await picker.inputValue(),'24');
    await page.getByRole('button',{name:'Riwayat riset',exact:true}).click();
    await page.getByText('Pertanyaan tersimpan',{exact:true}).waitFor();
    assert.equal(await picker.inputValue(),'24');
    failSend=true;
    await page.getByRole('textbox',{name:'Pesan'}).fill('Konteks pilihan');
    const before=sends.length;
    await page.getByRole('button',{name:'Kirim',exact:true}).click();
    await page.getByText('Jaringan terputus',{exact:true}).waitFor();
    assert.equal(await picker.isDisabled(),true);
    await page.getByRole('button',{name:'Coba kirim lagi',exact:true}).click();
    await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
    assert.deepEqual(sends[before],sends[before+1]);
    assert.equal(sends[before].analysis_record_id,24);
    assert.equal(await picker.isDisabled(),true);
    assert.equal(await page.getByRole('button',{name:'Lepas konteks',exact:true}).isDisabled(),true);
    await page.getByRole('button',{name:'+ Chat baru',exact:true}).click();
    assert.equal(await picker.isDisabled(),true,'global unresolved active request blocks retargeting');
    await page.getByRole('button',{name:'Buka permintaan aktif',exact:true}).click();
    await page.getByRole('button',{name:'Batalkan',exact:true}).click();
    await page.getByText('Dibatalkan',{exact:true}).waitFor();
    await picker.selectOption('3');
    await page.getByRole('button',{name:'Buat ulang jawaban',exact:true}).click();
    await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
    assert.equal(sends.at(-1).analysis_record_id,24,'regeneration retains admitted context after picker changes');
    await page.getByRole('button',{name:'Batalkan',exact:true}).click();
    await page.getByText('Dibatalkan',{exact:true}).waitFor();
    await page.getByRole('button',{name:'Lepas konteks',exact:true}).click();
    assert.equal(await picker.inputValue(),'');
    await page.getByRole('textbox',{name:'Pesan'}).fill('Tanpa konteks');
    await page.getByRole('button',{name:'Kirim',exact:true}).click();
    await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
    assert.equal(Object.hasOwn(sends.at(-1),'analysis_record_id'),false);
    await page.getByRole('button',{name:'Batalkan',exact:true}).click();
    await page.getByText('Dibatalkan',{exact:true}).waitFor();
  }
  let releaseAnalyses;
  analysisGate=new Promise(resolve=>{releaseAnalyses=resolve;});
  await page.goto('http://127.0.0.1:3213/workspace/assistant?analysis_record_id=99');
  await page.getByText('Memuat analisis…',{exact:true}).waitFor();
  await page.getByRole('button',{name:'Lepas konteks',exact:true}).click();
  releaseAnalyses(); analysisGate=undefined;
  await page.getByRole('option',{name:'Analisis #3 · completed',exact:true}).waitFor({state:'attached'});
  assert.equal(await page.getByRole('combobox',{name:'Pilih analisis',exact:true}).inputValue(),'','late fetch cannot restore cleared selection');
  analysisGate=new Promise(resolve=>{releaseAnalyses=resolve;});
  await page.getByRole('button',{name:'Muat analisis lainnya',exact:true}).click();
  await page.getByText('Memuat analisis…',{exact:true}).waitFor();
  await page.goto('about:blank');
  releaseAnalyses(); analysisGate=undefined;
  failAnalyses=true;
  await page.goto('http://127.0.0.1:3213/workspace/assistant?analysis_record_id=99');
  await page.getByText('Daftar analisis terputus',{exact:true}).waitFor();
  const picker=page.getByRole('combobox',{name:'Pilih analisis',exact:true});
  assert.equal(await picker.inputValue(),'99');
  failAnalyses=false;emptyAnalyses=true;
  await page.getByRole('button',{name:'Coba muat analisis lagi',exact:true}).click();
  await page.getByText('Belum ada analisis milik Anda.',{exact:true}).waitFor();
  assert.equal(await picker.inputValue(),'99');
  console.log('PASS both roles owner listing/pagination/deduplication/selection/clear, initial context, errors/retry/empty, immutable retry/regeneration, disabled global active context');
  const callsBeforeLegacy=analysisCalls.length;
  mode=undefined; enabled=false; emptyAnalyses=false; state='completed'; originalContextId=null; sends.length=0;
  await context.addCookies([{name:'deepct_session',value:'fake-user',url:'http://127.0.0.1:3213',httpOnly:true}]);
  await page.goto('http://127.0.0.1:3213/workspace/assistant');
  await page.getByText(/belum tersedia/).waitFor({timeout:20000});
  await page.getByRole('button',{name:'Riwayat riset',exact:true}).click();
  await page.getByText('Pertanyaan tersimpan',{exact:true}).waitFor();
  await page.getByText('Jawaban eksperimen',{exact:true}).waitFor();
  await page.getByRole('button',{name:'Salin pesan 101',exact:true}).click();
  await page.getByRole('button',{name:'Salin pesan 101',exact:true}).getByText('Tersalin',{exact:true}).waitFor();
  assert.equal(await page.evaluate(()=>navigator.clipboard.readText()),'Jawaban eksperimen');
  assert.equal(await page.getByRole('button',{name:'Kirim',exact:true}).isDisabled(),true);
  await page.getByRole('button',{name:'Pesan lebih lama',exact:true}).click();
  await page.getByText('Pesan lama',{exact:true}).waitFor();
  await page.getByText('Sumber dan metrik tepercaya',{exact:true}).click();
  await page.getByText('50.0 detik',{exact:false}).waitFor();
  const evidence=page.locator('.assistant-evidence');
  await evidence.getByText('Metadata ini dicatat saat jawaban dibuat, bukan status terkini.',{exact:false}).waitFor();
  const ssim=evidence.locator('.assistant-evidence__fact').filter({has:page.locator('dt').filter({hasText:/^ssim$/})});
  assert.equal(await ssim.locator('dd').innerText(),'0');
  assert.equal(await page.getByRole('complementary',{name:'Riwayat percakapan'}).evaluate(el=>Math.round(el.getBoundingClientRect().width)),270);
  await page.getByRole('button',{name:'Percakapan berikutnya'}).click();
  await page.getByRole('button',{name:'Percakapan lama',exact:true}).waitFor();
  await mkdir('/tmp/task-3-screenshots',{recursive:true});
  await page.screenshot({path:'/tmp/task-3-screenshots/next-desktop.png',fullPage:true});
  console.log('PASS disabled history, source metadata, 270px sidebar, message/conversation pagination');

  enabled=true;state='processing';failPoll=true;
  await page.reload();
  await page.getByRole('button',{name:'Riwayat riset',exact:true}).click();
  await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
  await page.getByText('Jaringan polling terputus',{exact:true}).waitFor({timeout:12000});
  assert.equal(await page.getByRole('button',{name:'Kirim',exact:true}).isDisabled(),true);
  failPoll=false;
  await page.getByRole('button',{name:'Coba polling lagi'}).click();
  await page.getByRole('button',{name:'+ Chat baru',exact:true}).click();
  await page.getByRole('textbox',{name:'Pesan'}).fill('Pesan baru');
  assert.equal(await page.getByRole('button',{name:'Kirim',exact:true}).isDisabled(),true);
  await page.getByRole('button',{name:'Buka permintaan aktif',exact:true}).click();
  await page.getByRole('button',{name:'Batalkan',exact:true}).click();
  await page.getByText('Dibatalkan',{exact:true}).waitFor();
  console.log('PASS restored active request, poll error/retry, disabled send, cancel');

  failSend=true;
  await page.goto('http://127.0.0.1:3213/workspace/assistant?analysis_record_id=3');
  await page.getByRole('textbox',{name:'Pesan'}).fill('Jelaskan hasil');
  await page.getByRole('button',{name:'Kirim',exact:true}).click();
  await page.getByText('Jaringan terputus',{exact:true}).waitFor();
  await page.getByRole('button',{name:'Coba kirim lagi',exact:true}).click();
  await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
  assert.deepEqual(sends[0],sends[1]);assert.equal(sends[0].analysis_record_id,3);
  assert.equal(await page.getByText('Jelaskan hasil',{exact:true}).count(),1);
  await page.getByRole('button',{name:'Batalkan',exact:true}).click();
  await page.getByText('Dibatalkan',{exact:true}).waitFor();
  console.log('PASS transport retry reuses key/payload/context, unique persisted message');

  state='failed';await page.reload();
  await page.getByRole('button',{name:'Riwayat riset',exact:true}).click();
  await page.getByText(/provider_timeout/).waitFor();
  await page.getByRole('button',{name:'Buat ulang jawaban',exact:true}).click();
  await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
  assert.notEqual(sends.at(-1).idempotency_key,sends[0].idempotency_key);
  await page.getByRole('button',{name:'Batalkan',exact:true}).click();
  await page.getByText('Dibatalkan',{exact:true}).waitFor();
  console.log('PASS explicit regeneration uses a fresh key');

  refuseSend=true;
  await page.getByRole('textbox',{name:'Pesan'}).fill('Koreksi konteks');
  await page.getByRole('button',{name:'Kirim',exact:true}).click();
  await page.getByText('Konteks tidak ditemukan',{exact:true}).waitFor();
  assert.equal(await page.getByRole('textbox',{name:'Pesan'}).isEnabled(),true);
  await page.getByRole('button',{name:'Lepas konteks',exact:true}).click();
  assert.equal(await page.getByText('Konteks prediksi #3',{exact:true}).count(),0);
  console.log('PASS definitive admission refusal preserves editable draft/context removal');

  await context.addCookies([{name:'deepct_session',value:'fake-admin',url:'http://127.0.0.1:3213',httpOnly:true}]);
  await page.reload();
  assert.equal(await page.getByRole('link',{name:'Asisten riset',exact:true}).count(),1);
  assert.equal(await page.getByRole('link',{name:'Predictions',exact:true}).count(),0);
  await page.setViewportSize({width:390,height:844});
  await page.getByRole('button',{name:'Riwayat percakapan',exact:true}).click();
  await page.getByRole('button',{name:'Riwayat riset',exact:true}).click();
  await page.getByText('Pertanyaan tersimpan',{exact:true}).waitFor();
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  await page.screenshot({path:'/tmp/task-3-screenshots/next-mobile.png',fullPage:true});
  await page.getByRole('button',{name:'Toggle navigation'}).click();
  await page.getByRole('link',{name:'Asisten riset',exact:true}).waitFor({state:'visible'});
  console.log('PASS admin own assistant navigation, retired prediction nav, mobile drawer/no horizontal overflow');

  await page.keyboard.press('Escape');
  await page.setViewportSize({width:1440,height:1000});
  for (const terminal of ['failed','cancelled']) {
    for (const entryContext of [null,9,'removed']) {
      state=terminal; originalContextId=3;
      await page.goto('http://127.0.0.1:3213/workspace/assistant'+(entryContext == null ? '' : '?analysis_record_id=9'));
      await page.getByRole('button',{name:'Riwayat riset',exact:true}).click();
      await page.getByRole('button',{name:'Buat ulang jawaban',exact:true}).waitFor();
      if(entryContext === 'removed') {
        await page.getByRole('button',{name:'Lepas konteks',exact:true}).click();
      }
      await page.getByRole('button',{name:'Buat ulang jawaban',exact:true}).click();
      await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
      assert.equal(sends.at(-1).analysis_record_id,3,terminal+' history must keep original context through entry '+entryContext);
      assert.equal(sends.at(-1).content,'Pertanyaan tersimpan');
      await page.getByRole('button',{name:'Batalkan',exact:true}).click();
      await page.getByText('Dibatalkan',{exact:true}).waitFor();
    }
  }
  for (const terminal of ['failed','cancelled']) {
    state=terminal; originalContextId=null;
    await page.goto('http://127.0.0.1:3213/workspace/assistant?analysis_record_id=9');
    await page.getByRole('button',{name:'Riwayat riset',exact:true}).click();
    await page.getByRole('button',{name:'Buat ulang jawaban',exact:true}).click();
    await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
    assert.equal(Object.hasOwn(sends.at(-1),'analysis_record_id'),false,'context-free history cannot acquire composer context');
    await page.getByRole('button',{name:'Batalkan',exact:true}).click();
    await page.getByText('Dibatalkan',{exact:true}).waitFor();
  }
  console.log('PASS failed/cancelled history regeneration preserves original context through ordinary/different entry and explicit composer removal; context-free original stays context-free');

  state='processing'; originalContextId=3;
  await page.goto('http://127.0.0.1:3213/workspace/assistant?analysis_record_id=9');
  await page.getByRole('button',{name:'Riwayat riset',exact:true}).click();
  await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
  assert.equal(await page.getByRole('button',{name:'Lepas konteks',exact:true}).isDisabled(),true);
  state='failed';
  await page.getByRole('button',{name:'Buat ulang jawaban',exact:true}).waitFor({timeout:12000});
  await page.getByRole('button',{name:'Lepas konteks',exact:true}).click();
  const previousKey=sends.at(-1).idempotency_key;
  await page.getByRole('button',{name:'Buat ulang jawaban',exact:true}).click();
  await page.getByRole('button',{name:'Batalkan',exact:true}).waitFor();
  assert.equal(sends.at(-1).analysis_record_id,3,'polling must retain original context independently of composer removal');
  assert.notEqual(sends.at(-1).idempotency_key,previousKey);
  await page.getByRole('button',{name:'Batalkan',exact:true}).click();
  await page.getByText('Dibatalkan',{exact:true}).waitFor();
  assert.equal(analysisCalls.length,callsBeforeLegacy,'legacy/default mode must not fetch analyses');
  console.log('PASS polling restores original context for regeneration after composer removal with a fresh key');
} finally {
  await browser?.close();app.kill('SIGTERM');await new Promise(resolve=>fixture.close(resolve));
}
