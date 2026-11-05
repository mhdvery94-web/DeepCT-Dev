import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const component = fs.readFileSync(
  new URL("../src/components/prediction-workspace.tsx", import.meta.url),
  "utf8",
);
const css = fs.readFileSync(
  new URL("../src/app/globals.css", import.meta.url),
  "utf8",
);

test("prediction preview keeps a labelled back action at the top", () => {
  assert.match(component, /← Back to prediction history/);
  assert.match(component, /prediction-review__header/);
  assert.match(css, /\.prediction-review__header\s*\{[^}]*position:\s*sticky/);
});

test("prediction back action becomes full width on phones", () => {
  assert.match(css, /@media \(max-width: 650px\)[\s\S]*?\.prediction-review__back\s*\{\s*width:\s*100%/);
});
