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
  assert.deepEqual(regenerationSubmission({content:'Pertanyaan asli'},{analysis_record_id:null,sources:[{id:9}]},'new-key'),{content:'Pertanyaan asli',idempotency_key:'new-key'});
});
