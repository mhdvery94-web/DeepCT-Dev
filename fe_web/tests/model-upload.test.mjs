import assert from 'node:assert/strict';
import test from 'node:test';
import { createHash } from 'node:crypto';
import { hashModelFile, transferModel, validateModelFile, CHUNK_BYTES } from '../src/lib/model-upload.ts';

function file(size = CHUNK_BYTES + 40) {
  const bytes = new Uint8Array(size); bytes.set([0x89, 0x48, 0x44, 0x46, 13, 10, 26, 10]);
  const source = new File([bytes], 'weights.h5');
  source.arrayBuffer = () => { throw Error('whole-file read forbidden'); };
  const original = source.slice.bind(source);
  source.slice = (start, end) => { assert.ok(end - start <= CHUNK_BYTES); return original(start, end); };
  return {source, bytes};
}

test('hashing is incremental and unsupported files fail before transfer', async () => {
  const {source, bytes} = file();
  const phases = [];
  assert.equal(await hashModelFile(source, p => phases.push(p)), createHash('sha256').update(bytes).digest('hex'));
  assert.equal(phases.at(-1), 100);
  await assert.rejects(validateModelFile(new File(['x'], 'evil.py')), /h5|keras/);
});

test('resume verifies digest, reconciles offset and never copies login credentials', async () => {
  const {source} = file();
  const sha256 = await hashModelFile(source, () => {});
  let offset = 100, sent = 0;
  const session = {id: 7, upload_url: 'https://tuf.example/prefix/uploads/uuid', token: 'capability', offset,
    manifest: {sha256, size_bytes: source.size, weight_file: 'model.h5'}, state: 'uploading'};
  const control = async path => { assert.match(path, /^\/admin\/model-uploads\/7/); return {...session, offset}; };
  const direct = async (url, options) => {
    assert.equal(url, session.upload_url); assert.equal(options.credentials, 'omit'); assert.equal(options.redirect, 'error');
    assert.deepEqual(Object.keys(options.headers).sort(), ['Authorization', 'Content-Type', 'Upload-Offset']);
    assert.equal(options.headers.Authorization, 'Bearer capability');
    assert.equal(Number(options.headers['Upload-Offset']), offset);
    offset += options.body.size; sent++;
    if (sent === 1) throw Error('response lost after server accepted bytes');
    return new Response(JSON.stringify({offset}), {status: 200});
  };
  const result = await transferModel(source, session, {control, direct, progress: () => {}});
  assert.equal(result.offset, source.size);
  await assert.rejects(transferModel(file(50).source, session, {control, direct, progress: () => {}}), /identity|digest/);
});

test('direct transport refuses non-HTTPS URLs', async () => {
  const {source} = file(50);
  await assert.rejects(transferModel(source, {id: 1, upload_url: 'http://evil', manifest: {size_bytes: 50,
    sha256: await hashModelFile(source, () => {}), weight_file: 'model.h5'}}, {control: async () => {throw Error('unexpected');}, direct: fetch, progress: () => {}}), /HTTPS/);
});

test('resume rejects corrupt server offsets instead of reporting a completed upload', async () => {
  const {source} = file(50);
  const session = {id: 1, state: 'uploading', upload_url: 'https://tuf/uploads/id', manifest: {
    sha256: await hashModelFile(source, () => {}), size_bytes: 50, weight_file: 'model.h5'}};
  for (const offset of [51, -1, NaN]) {
    await assert.rejects(transferModel(source, session, {control: async () => ({...session, offset}),
      direct: async () => { throw Error('unexpected transfer'); }, progress: () => {}}), /offset/i);
  }
});
