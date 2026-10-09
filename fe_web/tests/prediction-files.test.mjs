import test from "node:test";
import assert from "node:assert/strict";
import { unzipSync } from "fflate";
import { preparePredictionArchive, validatePredictionFiles } from "../src/lib/prediction-files.ts";

const frame = (name, data = [73, 73, 42, 0, 1, 2], lastModified = 100) => new File([new Uint8Array(data)], name, { lastModified });

test("TIFF selections produce a readable ZIP preserving original names and bytes", async () => {
  const files = [frame("frame_005.TIFF"), frame("échantillon_001.tif", [1, 2, 3, 255])];
  const progress = [];
  const archive = await preparePredictionArchive(files, (value) => progress.push(value));
  const entries = unzipSync(new Uint8Array(await archive.arrayBuffer()));
  assert.deepEqual(Object.keys(entries).sort(), files.map((file) => file.name).sort());
  for (const file of files) assert.deepEqual(entries[file.name], new Uint8Array(await file.arrayBuffer()));
  assert.equal(progress.at(-1), 100);
  assert.equal(archive.type, "application/zip");
});

test("reselecting the same TIFFs retains resumable archive identity regardless of picker order", async () => {
  const files = [frame("frame_001.tif"), frame("frame_005.tif", [5, 6, 7])];
  const first = await preparePredictionArchive(files);
  const second = await preparePredictionArchive([...files].reverse());
  assert.equal(first.name, second.name);
  assert.equal(first.lastModified, second.lastModified);
  assert.deepEqual(await first.arrayBuffer(), await second.arrayBuffer());
  const changed = await preparePredictionArchive([files[0], frame("frame_005.tif", [8, 9, 0])]);
  assert.notEqual(first.name, changed.name, "different bytes must not reuse another dataset's upload");
});

test("a ZIP is passed through without requiring the browser's MIME detection", async () => {
  const archive = new File(["zip bytes"], "scan.ZIP", { type: "application/octet-stream" });
  assert.equal(await preparePredictionArchive([archive]), archive);
});

test("mixed selections, duplicates, unnumbered frames and empty inputs are refused", () => {
  assert.throws(() => validatePredictionFiles([]), /Choose/);
  assert.throws(() => validatePredictionFiles([frame("scan.zip"), frame("frame_001.tif")]), /mix/);
  assert.throws(() => validatePredictionFiles([frame("frame_001.tif")]), /at least two/);
  assert.throws(() => validatePredictionFiles([frame("frame_001.tif"), frame("FRAME_001.TIF")]), /unique/);
  assert.throws(() => validatePredictionFiles([frame("frame.tif"), frame("other.tiff")]), /frame number/);
  assert.throws(() => validatePredictionFiles([frame("../frame_001.tif"), frame("frame_003.tif")]), /simple names/);
  assert.throws(() => validatePredictionFiles([new File([], "scan.zip")]), /Empty/);
});

test("file-size limits are enforced before reading TIFF bytes", () => {
  const oversized = frame("frame_001.tif");
  Object.defineProperty(oversized, "size", { value: 50 * 1024 ** 2 + 1 });
  assert.throws(() => validatePredictionFiles([oversized, frame("frame_003.tif")]), /50 MB/);
  const archive = frame("scan.zip");
  Object.defineProperty(archive, "size", { value: 2 * 1024 ** 3 + 1 });
  assert.throws(() => validatePredictionFiles([archive]), /2 GB/);
});

test("preparation can be paused between bounded reads", async () => {
  const controller = new AbortController();
  const large = new File([new Uint8Array(3 * 1024 ** 2)], "frame_001.tif");
  await assert.rejects(preparePredictionArchive([large, frame("frame_005.tif")], () => controller.abort(), controller.signal), { name: "AbortError" });
});
