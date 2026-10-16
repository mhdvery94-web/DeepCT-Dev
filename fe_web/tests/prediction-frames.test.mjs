import test from 'node:test';
import assert from 'node:assert/strict';
import { parsePredictionFrames, filterPredictionFrames, frameKindLabel, framePreviewUrl } from '../src/lib/prediction-frames.ts';

const frame = (name, kind, size = 1024) => ({ name, kind, size });
const mixed = [frame('frame10.tif', 'output'), frame('frame2.tif', 'output'), frame('frame1.tif', 'input'), frame('frame2.tif', 'input')];

test('combined frames follow numeric frame order without mutating API data', () => {
  const original = structuredClone(mixed);
  const frames = parsePredictionFrames(mixed);
  assert.deepEqual(filterPredictionFrames(frames, 'all').map(({ name, kind }) => [name, kind]), [['frame1.tif', 'input'], ['frame2.tif', 'input'], ['frame2.tif', 'output'], ['frame10.tif', 'output']]);
  assert.deepEqual(mixed, original);
});

test('frame number is the last digit sequence, including different prefixes and large numbers', () => {
  assert.deepEqual(parsePredictionFrames([frame('scan9_10.tif', 'input'), frame('zscan1_2.tif', 'output'), frame('scan_9007199254740993.tif', 'output'), frame('scan_9007199254740992.tif', 'input')]).map(({ name }) => name), ['zscan1_2.tif', 'scan9_10.tif', 'scan_9007199254740992.tif', 'scan_9007199254740993.tif']);
});

test('kind filters preserve ordered input and generated frames', () => {
  const frames = parsePredictionFrames(mixed);
  assert.deepEqual(filterPredictionFrames(frames, 'input').map(({ name }) => name), ['frame1.tif', 'frame2.tif']);
  assert.deepEqual(filterPredictionFrames(frames, 'output').map(({ name }) => name), ['frame2.tif', 'frame10.tif']);
});

test('only authoritative known kinds receive Input or AI labels', () => {
  assert.equal(frameKindLabel('input'), 'Input'); assert.equal(frameKindLabel('output'), 'AI');
  for (const value of ['AI', 'generated', '', undefined, null, {}, 0]) assert.equal(frameKindLabel(value), undefined);
  assert.equal(frameKindLabel(parsePredictionFrames([frame('generated999.tif', 'input')])[0].kind), 'Input');
});

test('same-number same-name frames survive across kinds with distinct encoded PNG preview URLs', () => {
  const frames = parsePredictionFrames([frame('frame 2#.tif', 'output'), frame('frame 2#.tif', 'input'), frame('frame 2#.tif', 'input')]);
  assert.equal(frames.length, 2);
  assert.equal(framePreviewUrl(42, frames[0], 128), '/api/backend/predictions/42/frames/frame%202%23.tif/preview?kind=input&size=128');
  assert.equal(framePreviewUrl(42, frames[1], 1024), '/api/backend/predictions/42/frames/frame%202%23.tif/preview?kind=output&size=1024');
});

test('malformed rows and unsafe names are rejected without fabricated AI labels', () => {
  const malformed = [null, undefined, 42, [], {}, frame('x2.tif', 'AI'), frame('x2.tif', undefined), frame(2, 'output'), frame('../x2.tif', 'output'), frame('x\\2.tif', 'output'), frame('x\0.tif', 'output'), frame('', 'input'), frame('x2.png', 'output')];
  assert.deepEqual(parsePredictionFrames(malformed), []);
  for (const value of [null, {}, 'frames', undefined]) assert.deepEqual(parsePredictionFrames(value), []);
  assert.deepEqual(parsePredictionFrames([frame('frame2.tif', 'output', -4)])[0].size, undefined);
});

test('lone high and low Unicode surrogates are rejected before preview rendering', () => {
  const names = ['\ud800.tif', '\udc00.tif', 'frame2\ud800.tif', 'frame2\udc00.tif', '\udc00\ud800.tif'];
  assert.deepEqual(parsePredictionFrames(names.map(name => frame(name, 'output'))), []);
});

test('valid Unicode including a surrogate pair retains its exact name and safe preview URL', () => {
  const name = 'frame2\ud83d\udd2c.tif';
  const frames = parsePredictionFrames([frame(name, 'input'), frame('échantillon_3.tif', 'output')]);
  assert.deepEqual(frames.map(frame => frame.name), [name, 'échantillon_3.tif']);
  assert.equal(framePreviewUrl(42, frames[0], 128), '/api/backend/predictions/42/frames/frame2%F0%9F%94%AC.tif/preview?kind=input&size=128');
  assert.equal(framePreviewUrl(42, frames[1], 1024), '/api/backend/predictions/42/frames/%C3%A9chantillon_3.tif/preview?kind=output&size=1024');
});
