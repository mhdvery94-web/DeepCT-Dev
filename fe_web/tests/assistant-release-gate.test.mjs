import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

test("production portal keeps the unreleased assistant behind a development page", () => {
  const page = read("src/app/(portal)/workspace/assistant/page.tsx");
  const navigation = read("src/components/portal-shell.tsx");
  const predictions = read("src/components/prediction-workspace.tsx");

  assert.match(page, /Dalam Pengembangan/);
  assert.match(page, /validasi kualitas, keamanan/);
  assert.doesNotMatch(page, /ResearchAssistant/);
  assert.doesNotMatch(navigation, /\["\/workspace\/assistant"/);
  assert.doesNotMatch(predictions, /Jelaskan hasil dengan asisten/);
});
