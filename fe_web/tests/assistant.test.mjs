import test from 'node:test';
import assert from 'node:assert/strict';
import { activeRequest, mergeMessages, providerMetric, regenerationSubmission } from '../src/lib/assistant.ts';

test('merging older history and replayed persisted messages keeps chronological unique IDs', () => {
  assert.deepEqual(mergeMessages([{id:2,content:'current'}],[{id:1,content:'old'},{id:2,content:'current'}]).map(message=>message.id),[1,2]);
});
test('queued and processing block admissions, terminal requests do not',()=>{
  for(const status of ['queued','processing']) assert.equal(activeRequest({status}),true);
  for(const status of ['completed','failed','cancelled']) assert.equal(activeRequest({status}),false);
});
test('provider durations are nanoseconds and absent/null metrics stay unavailable',()=>{
  assert.equal(providerMetric('total_duration',50000000000),'50.0 detik');
  assert.equal(providerMetric('eval_count',0),'0');
  assert.equal(providerMetric('total_duration',null),'Tidak tersedia');
  assert.equal(providerMetric('eval_count',undefined),'Tidak tersedia');
});
test('regeneration uses immutable original selection even when failed/cancelled sources are empty',()=>{
  for(const status of ['failed','cancelled']) {
    const original={analysis_record_id:3,status,sources:[]};
    assert.deepEqual(regenerationSubmission({content:'Pertanyaan asli'},original,'new-key'),{content:'Pertanyaan asli',idempotency_key:'new-key',analysis_record_id:3});
  }
});
test('a null original context is never reconstructed from a source or composer',()=>{
  assert.deepEqual(regenerationSubmission({content:'Pertanyaan asli'},{analysis_record_id:null,sources:[{id:9}]},'new-key'),{content:'Pertanyaan asli',idempotency_key:'new-key',analysis_record_id:null});
});

test('composer distinguishes inherited omission, explicit clear and selected ID', async()=>{
  const {contextSubmission}=await import('../src/lib/assistant.ts');
  assert.deepEqual(contextSubmission('Pesan','k',undefined),{content:'Pesan',idempotency_key:'k'});
  assert.deepEqual(contextSubmission('Pesan','k',null),{content:'Pesan',idempotency_key:'k',analysis_record_id:null});
  assert.deepEqual(contextSubmission('Pesan','k',3),{content:'Pesan',idempotency_key:'k',analysis_record_id:3});
});
test('unknown errors never reveal raw paths, JSON or parser exceptions',async()=>{
  const {assistantErrorMessage,requestFailureLabel}=await import('../src/lib/assistant.ts');
  assert.equal(assistantErrorMessage('Jaringan terputus'),'Jaringan terputus');
  for(const value of ['/etc/private','{"exception":"bad"}','TypeError: invalid data',{},null]) assert.equal(assistantErrorMessage(value),'Permintaan tidak dapat diselesaikan. Coba lagi.');
  assert.equal(requestFailureLabel('/etc/private'),'Jawaban gagal dibuat');
  assert.match(requestFailureLabel('provider_timeout'),/provider_timeout/);
});
test('picker distinguishes follow-up inheritance from an explicit clear',async()=>{
  const {contextSelection}=await import('../src/lib/assistant.ts');
  assert.equal(contextSelection('inherit'),undefined);
  assert.equal(contextSelection(''),null);
  assert.equal(contextSelection('24'),24);
  assert.equal(contextSelection('malformed'),undefined);
});

test('metadata mode describes bounded evidence-grounded replies and keeps scientific limits', async () => {
  const fs = await import('node:fs');
  const source = fs.readFileSync(new URL('../src/components/research-assistant.tsx', import.meta.url), 'utf8');
  const disclaimer = source.match(/status\.mode === "metadata"\s*\? "([^"]+)"/)?.[1];
  assert.ok(disclaimer, 'metadata-only disclaimer is present');
  for (const text of ['Asisten berbasis bukti', 'snapshot', 'saat jawaban dibuat', 'bukan status terkini', 'tidak membaca piksel TIFF', 'tidak menjamin kebenaran ilmiah']) assert.ok(disclaimer.includes(text), text);
  const welcome = source.match(/status\?\.mode === "metadata"\s*\? "([^"]+)"/)?.[1];
  assert.match(welcome ?? '', /Jawaban berbasis bukti metadata dan SOP/);
});
