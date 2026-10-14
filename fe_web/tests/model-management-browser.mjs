// Local Chromium/HTTP fixture exercises the real management form and BFF.
import assert from 'node:assert/strict';
import http from 'node:http';
import {spawn} from 'node:child_process';
import {chromium} from '/workspace/.browser-tools/node_modules/playwright-core/index.mjs';
const mode=process.argv[2] ?? 'all';
const session=(id,state='ready_for_activate')=>({id,state,published:true,offset:100,manifest:{model_id:id===1?'old-model':'model-'+id,version:'1.0.0',name:'Session '+id,description:''}});
let held, delayA=true, createdSession;
const mutations=[], creates=[];
let createFails=true;
const fixture=http.createServer(async(req,res)=>{
 const url=new URL(req.url,'http://127.0.0.1'), path=url.pathname.replace(/^\/api/,'');
 const send=(data,extra={},status=200)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify({success:status<400,data,...extra}));};
 if(path==='/user') return send({id:1,name:'Admin',email:'admin@example.test',role:'admin',must_change_password:false});
 if(path==='/admin/models') return send([]);
 if(path==='/admin/model-uploads' && req.method==='GET') {
  const page=Number(url.searchParams.get('page')||1), search=url.searchParams.get('search');
  return send(search?[session(1)]:page===3?[session(1,'active'),session(2)]:[session(3),session(2),session(1)],{pagination:{current_page:page,last_page:search?1:3,total:105}});
 }
 if(path==='/admin/model-uploads' && req.method==='POST') {
  let body='';for await(const chunk of req)body+=chunk;
  const manifest=JSON.parse(body);creates.push(manifest);
  if(createFails){createFails=false;return send(null,{message:'Create response lost'},503);}
  const {creation_key, ...exactManifest}=manifest; assert.ok(creation_key);
  createdSession={...session(4,'uploaded'),published:false,manifest:exactManifest,upload_url:'https://tuf.example/uploads/4',offset:manifest.size_bytes};
  return send(createdSession, {},201);
 }
 if(path==='/admin/model-uploads/1' && delayA){held=()=>send(session(1,'active'));return;}
 if(path==='/admin/model-uploads/4')return send(createdSession);
 if(/^\/admin\/model-uploads\/\d+$/.test(path))return send(session(Number(path.split('/').at(-1)),path.endsWith('/1')?'active':'ready_for_activate'));
 if(/^\/admin\/model-uploads\/\d+\/(activate|deactivate)$/.test(path)){mutations.push(path);return send(session(Number(path.split('/')[3])));}
 return send(null,{message:'missing '+path},404);
});
await new Promise(r=>fixture.listen(8234,'127.0.0.1',r));
const app=spawn(process.execPath,['node_modules/next/dist/bin/next','dev','--hostname','127.0.0.1','--port','3234'],{env:{...process.env,LARAVEL_API_BASE_URL:'http://127.0.0.1:8234/api'},stdio:['ignore','pipe','pipe']});
let log='';app.stdout.on('data',c=>log+=c);app.stderr.on('data',c=>log+=c);
let browser;
try {
 for(let i=0;i<160;i++){if(log.includes('Ready in'))break;if(app.exitCode!==null)throw Error(log);await new Promise(r=>setTimeout(r,250));}
 browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 const context=await browser.newContext({reducedMotion:'reduce'});await context.addCookies([{name:'deepct_session',value:'fake-admin',url:'http://127.0.0.1:3234',httpOnly:true}]);
 const page=await context.newPage();page.setDefaultTimeout(7000);await page.goto('http://127.0.0.1:3234/admin/models');
 const selector=page.getByLabel('Sesi tersimpan');await selector.locator('option[value="1"]').waitFor({state:'attached'});
 if(mode==='all'||mode==='selection') {
  held=null; {const requested=page.waitForRequest(r=>r.url().endsWith('/model-uploads/1'));await selector.selectOption('1');await requested;}
  for(let i=0;!held && i<100;i++)await new Promise(r=>setTimeout(r,10));assert.ok(held);
  await selector.selectOption('2');await page.waitForFunction(()=>document.querySelector('input[name=model_id]')?.value==='model-2');
  const response=page.waitForResponse(r=>r.url().endsWith('/model-uploads/1'));held();await response;await page.waitForTimeout(100);
  assert.equal(await page.getByLabel('ID model',{exact:true}).inputValue(),'model-2');
  held=null; {const requested=page.waitForRequest(r=>r.url().endsWith('/model-uploads/1'));await selector.selectOption('1');await requested;}
  for(let i=0;!held && i<100;i++)await new Promise(r=>setTimeout(r,10));assert.ok(held);
  await selector.selectOption('');const second=page.waitForResponse(r=>r.url().endsWith('/model-uploads/1'));held();await second;await page.waitForTimeout(100);
  assert.equal(await selector.inputValue(),'');assert.equal(await page.getByLabel('ID model',{exact:true}).inputValue(),'');
  console.log('PASS delayed A cannot replace B or New');
 }
 if(mode==='all'||mode==='pages') {
  delayA=false;
  await page.getByRole('button',{name:'Sesi berikutnya',exact:true}).click();await page.getByText('Halaman 2 / 3').waitFor();
  await page.getByRole('button',{name:'Sesi berikutnya',exact:true}).click();await page.getByText('Halaman 3 / 3').waitFor();
  await selector.selectOption('1');await page.getByRole('button',{name:'Nonaktifkan versi',exact:true}).click();
  await page.waitForTimeout(100);assert.equal(mutations.at(-1),'/admin/model-uploads/1/deactivate');
  await selector.selectOption('2');await page.getByRole('button',{name:'Aktifkan versi',exact:true}).click();
  await page.waitForTimeout(100);assert.equal(mutations.at(-1),'/admin/model-uploads/2/activate');
  await page.getByLabel('Cari sesi model / versi').fill('old-model');await page.getByRole('button',{name:'Cari sesi',exact:true}).click();await page.getByText('Halaman 1 / 1').waitFor();
  console.log('PASS pages beyond 100, owned old target action and search');
 }
 if(mode==='all'||mode==='create') {
  await selector.selectOption('');await page.getByLabel('ID model',{exact:true}).fill('retry-model');await page.getByLabel('Versi immutable (contoh 1.0.0)').fill('1.0.0');await page.getByLabel('Nama tampilan').fill('Retry');
  await page.getByLabel('File bobot',{exact:true}).setInputFiles({name:'model.h5',mimeType:'application/octet-stream',buffer:Buffer.from([137,72,68,70,13,10,26,10])});
  await page.getByRole('button',{name:'Hash & upload',exact:true}).click();await page.getByText('Create response lost',{exact:true}).waitFor();
  await page.getByRole('button',{name:'Hash & upload',exact:true}).click();await page.getByText(/Upload selesai/).waitFor();
  assert.equal(creates.length,2);assert.ok(creates[0].creation_key);assert.deepEqual(creates[0],creates[1]);console.log('PASS create retry preserves key and exact manifest');
 }
} finally {await browser?.close();app.kill('SIGTERM');fixture.closeAllConnections();fixture.close();}
