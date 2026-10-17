import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import ts from 'typescript';
import { renderToStaticMarkup } from 'react-dom/server';
import * as assistant from '../src/lib/assistant.ts';
const require = createRequire(import.meta.url);
const output = ts.transpileModule(fs.readFileSync(new URL('../src/components/assistant-evidence.tsx',import.meta.url),'utf8'), {compilerOptions:{jsx:ts.JsxEmit.ReactJSX,module:ts.ModuleKind.CommonJS}}).outputText;
const compiled = {exports:{}};
new Function('require','exports','module',output)((name)=> name==='@/lib/assistant'?assistant:require(name),compiled.exports,compiled);
const report = (changes={}) => ({schema_version:1,evaluation_status:'completed',metrics:{mae:2,rmse:3,psnr:40,ssim:0.934},metric_status:{psnr:'available',ssim:'available'},method:{sample_domain:'raw_uint16',data_range:65535,ssim:{window_size:7,weighting:'uniform',boundary:'valid',covariance:'sample',k1:0.01,k2:0.03}},reference:{source:'uploaded_midpoint',index:1,from:[0,2]},model:{name:'CT Model',version:'v1',provenance:'managed_manifest_sha256',sha256:'a'.repeat(64)},baseline:{status:'completed',metrics:{mae:1,rmse:2,psnr:45,ssim:0.95},metric_status:{psnr:'available',ssim:'available'},method:{baseline:'linear_midpoint',midpoint_rounding:'half_up'}},comparison:{status:'completed',precision:'recorded_precision',mae_reduction:-1,rmse_reduction:-1,psnr_gain_db:-5,ssim_gain:-0.016},...changes});
const source = (evaluation=report()) => ({type:'analysis_record',id:1,status:'completed',metrics:{mae:2,ssim:0.934},evaluation});
const render = sources => renderToStaticMarkup(compiled.exports.AssistantEvidence({request:{sources}}));
test('completed report shows recorded reference, method, model, baseline and signed regressions',()=>{
 const markup=render([source()]);
 for (const text of ['Evaluasi selesai','Midpoint unggahan #1','0 → 2','raw_uint16','65535','Jendela SSIM','uniform','valid','sample','0.01','0.03','CT Model','v1','managed_manifest_sha256','a'.repeat(64),'Baseline linear','half_up','-1','-5','recorded_precision','Nilai negatif berarti lebih buruk']) assert.ok(markup.includes(text),text);
});
for (const [state,label] of [['no_reference','Tidak ada referensi unggahan'],['evaluation_failed','Pengukuran gagal'],['legacy_unknown','Evaluasi historis tidak diketahui']]) {
 test(`report state ${state} stays explicit`,()=>assert.match(render([source(report({evaluation_status:state}))]),new RegExp(label)));
}
test('legacy source has explicit unknown evaluation and finite saved metrics',()=>{
 const markup=render([{...source(),evaluation:undefined,model:{provenance:'historical_model_snapshot_unavailable'},metrics:{ssim:0}}]);
 assert.match(markup,/Evaluasi historis tidak diketahui/); assert.match(markup,/Versi historis \/ provenans model tidak tersedia/); assert.match(markup,/<dt>SSIM<\/dt><dd>0<\/dd>/);
});
test('null PSNR is infinite only with recorded infinite status and small SSIM has a reason',()=>{
 const markup=render([source(report({metrics:{mae:0,rmse:0,psnr:null,ssim:null},metric_status:{psnr:'infinite',ssim:'image_too_small'}}))]);
 assert.match(markup,/Tak terhingga \(galat tepat nol\)/); assert.match(markup,/Citra terlalu kecil/);
 const absent=render([source(report({metrics:{psnr:null,ssim:null},metric_status:{}}))]);
 assert.doesNotMatch(absent,/Tak terhingga/); assert.match(absent,/<dt>PSNR \(dB\)<\/dt><dd>Tidak tersedia<\/dd>/);
});
test('document-only SOP citations render id version title and text without a prediction',()=>{
 const markup=render([{type:'document',id:'deepct-sop-metrics',version:'2026-10-16.v1',title:'Arti metrik',text:'SSIM memakai jendela 7.'}]);
 for(const value of ['Dokumen SOP','deepct-sop-metrics','2026-10-16.v1','Arti metrik','SSIM memakai jendela 7.','Tidak ada konteks prediksi']) assert.ok(markup.includes(value),value);
 assert.doesNotMatch(markup,/Prediksi #/);
});
test('parser ignores unknown malformed containers, unsafe text, raw errors and nonfinite metrics',()=>{
 const sources=[null,4,{type:'unexpected',error:'/etc/private'},source(report({method:{sample_domain:'/etc/private'},metrics:{ssim:'<script>',psnr:Infinity,mae:null},model:{name:'/etc/private'},reference:{index:1,from:['bad',2]}})),{type:'document',id:5,title:{},text:'/etc/private'}];
 const parsed=assistant.parseAiSources(sources); assert.equal(parsed.length,1); assert.equal(parsed[0].evaluation.metrics.ssim,null);
 const markup=render(sources); assert.doesNotMatch(markup,/\/etc|script|Infinity|undefined|\{"/);
 assert.doesNotThrow(()=>render({bad:true}));
});
test('saved source snapshot is independent from composer selection and parser never mutates input',()=>{
 const raw=[source()]; const original=JSON.stringify(raw); const parsed=assistant.parseAiSources(raw);
 raw[0].evaluation.metrics.mae=50;
 assert.equal(parsed[0].evaluation.metrics.mae,2); raw[0].evaluation.metrics.mae=2; assert.equal(JSON.stringify(raw),original);
 assert.match(render(raw),/Metadata ini dicatat saat jawaban dibuat, bukan status terkini/);
});

const sopDocuments = JSON.parse(fs.readFileSync(new URL('../../be/resources/ai/sop.json', import.meta.url), 'utf8')).documents;
assert.equal(sopDocuments.length, 5, 'exercise the complete controlled corpus');
for (const { id, version, title, text } of sopDocuments) {
 test(`actual SOP ${id} survives parsing and document-only rendering verbatim`, () => {
  const document = { type: 'document', id, version, title, text };
  assert.deepEqual(assistant.parseAiSources([document]), [document]);
  const markup = render([document]);
  for (const value of [id, version, title, text]) assert.ok(markup.includes(value), value);
  assert.match(markup, /Tidak ada konteks prediksi/);
  assert.doesNotMatch(markup, /Prediksi #/);
 });
}
test('document prose rejects unsafe content while metadata keeps strict slash restrictions', () => {
 const document = { type: 'document', id: 'deepct-sop-lifecycle', version: '2026-10-16.v1', title: 'Tahapan analisis', text: 'Pilih Mulai/Start setelah peninjauan.' };
 for (const value of ['/etc/private', '/secret', '../private', 'storage/private.tiff', 'storage/private/data', 'C:\\private', '<script>bad</script>', 'bad\u0000text', '{"error":"private"}', 'TypeError: invalid data', 'Stack trace: private']) {
  for (const field of ['title', 'text']) assert.deepEqual(assistant.parseAiSources([{ ...document, [field]: value }]), [], `${field}: ${value}`);
 }
 for (const [field, limit] of [['title', 120], ['text', 900]]) {
  for (const value of ['', {}, 'x'.repeat(limit + 1)]) assert.deepEqual(assistant.parseAiSources([{ ...document, [field]: value }]), [], `${field} is bounded prose`);
 }
 assert.deepEqual(assistant.parseAiSources([{ ...document, version: '2026/10' }]), []);
 const parsed = assistant.parseAiSources([source(report({ model: { name: 'Model/Private' }, method: { sample_domain: 'raw/uint16' } }))]);
 assert.deepEqual(parsed[0].evaluation.model, []);
 assert.deepEqual(parsed[0].evaluation.method, []);
});
