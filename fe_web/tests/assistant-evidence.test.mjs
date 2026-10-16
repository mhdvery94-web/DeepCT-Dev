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
test('historical snapshot absence renders explicit provenance without undefined metadata',()=>{
 const markup=renderToStaticMarkup(compiled.exports.AssistantEvidence({request:{sources:[{id:1,status:'completed',model:{id:7,provenance:'historical_model_snapshot_unavailable'},metrics:{}}]}}));
 assert.match(markup,/Versi historis \/ provenans model tidak tersedia/);
 assert.doesNotMatch(markup,/undefined · undefined/);
});

for (const [ssim, rendered] of [[0.934, '0.934'], [0, '0'], [null, 'Tidak tersedia'], ['<script>alert(1)</script>', '&lt;script&gt;alert(1)&lt;/script&gt;']]) {
 test(`evidence exposes saved SSIM ${JSON.stringify(ssim)} safely`,()=>{
  const markup=renderToStaticMarkup(compiled.exports.AssistantEvidence({request:{sources:[{id:1,status:'completed',metrics:{ssim}}]}}));
  assert.ok(markup.includes(`<dt>ssim</dt><dd>${rendered}</dd>`));
  assert.doesNotMatch(markup,/<script>/);
 });
}
test('evidence identifies the historical snapshot alongside neutral verification guidance',()=>{
 const markup=renderToStaticMarkup(compiled.exports.AssistantEvidence({request:{sources:[]}}));
 assert.match(markup,/Metadata ini dicatat saat jawaban dibuat, bukan status terkini/);
 assert.match(markup,/Gunakan sumber ini untuk memeriksa jawaban; asisten tidak membaca piksel TIFF/);
});
