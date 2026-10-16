export type PredictionFrame = { name: string; kind: "input" | "output"; size?: number };
export type FrameFilter = "all" | PredictionFrame["kind"];
const numeric = new Intl.Collator("en", { numeric: true });

/** Only API kinds carry provenance; filenames never decide whether a frame is AI. */
export function frameKindLabel(kind: unknown): "Input" | "AI" | undefined {
  return kind === "input" ? "Input" : kind === "output" ? "AI" : undefined;
}

export function parsePredictionFrames(value: unknown): PredictionFrame[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const frames: PredictionFrame[] = [];
  for (const row of value) {
    if (!row || typeof row !== "object" || !frameKindLabel(row.kind) || typeof row.name !== "string"
      || !/\.tiff?$/i.test(row.name) || /[\\/\x00-\x1f\x7f]/.test(row.name) || row.name.length > 255) continue;
    // Unpaired UTF-16 surrogates survive JSON but cannot form a preview URL.
    try { encodeURIComponent(row.name); } catch { continue; }
    const key = JSON.stringify([row.kind, row.name]);
    if (seen.has(key)) continue;
    seen.add(key);
    frames.push({ name: row.name, kind: row.kind, size: typeof row.size === "number" && Number.isFinite(row.size) && row.size >= 0 ? row.size : undefined });
  }
  return frames.sort((a, b) => {
    const aNumber = a.name.match(/\d+(?!.*\d)/)?.[0];
    const bNumber = b.name.match(/\d+(?!.*\d)/)?.[0];
    return (aNumber && bNumber ? numeric.compare(aNumber, bNumber) : aNumber ? -1 : bNumber ? 1 : 0)
      || numeric.compare(a.name, b.name) || (a.kind === b.kind ? 0 : a.kind === "input" ? -1 : 1);
  });
}

export function filterPredictionFrames(frames: PredictionFrame[], filter: FrameFilter): PredictionFrame[] {
  return frames.filter((frame) => filter === "all" || frame.kind === filter);
}

export function framePreviewUrl(predictionId: string | number, frame: PredictionFrame, size: 128 | 1024): string {
  return "/api/backend/predictions/" + encodeURIComponent(String(predictionId)) + "/frames/" + encodeURIComponent(frame.name) + "/preview?kind=" + frame.kind + "&size=" + size;
}
