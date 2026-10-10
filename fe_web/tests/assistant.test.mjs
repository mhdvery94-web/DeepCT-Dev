import test from 'node:test';
import assert from 'node:assert/strict';
import { activeRequest, mergeMessages, providerMetric } from '../src/lib/assistant.ts';

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
