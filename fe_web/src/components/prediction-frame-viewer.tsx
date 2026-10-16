"use client";

import { useEffect, useState } from "react";
import { backend, bytes, type Row } from "@/lib/client-api";
import { filterPredictionFrames, frameKindLabel, framePreviewUrl, parsePredictionFrames, type FrameFilter, type PredictionFrame } from "@/lib/prediction-frames";

export function PredictionFrameViewer({ predictionId, completed }: { predictionId: Row["id"]; completed: boolean }) {
  // A new prediction/status starts a fresh sequence and aborts the previous request.
  return <FrameSequence key={JSON.stringify([predictionId, completed])} predictionId={predictionId} completed={completed} />;
}

function FrameSequence({ predictionId, completed }: { predictionId: Row["id"]; completed: boolean }) {
  const [frames, setFrames] = useState<PredictionFrame[]>([]);
  const [kind, setKind] = useState<FrameFilter>(completed ? "all" : "input");
  const [index, setIndex] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [error, setError] = useState("");
  const [imageError, setImageError] = useState("");
  const [loading, setLoading] = useState(true);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    void backend("/predictions/" + encodeURIComponent(String(predictionId)) + "/frames", "GET", undefined, controller.signal)
      .then((response) => { if (!controller.signal.aborted) { setFrames(parsePredictionFrames(response.data)); setError(""); setLoading(false); } })
      .catch((reason) => { if (!controller.signal.aborted) { setError(reason instanceof Error ? reason.message : "Unable to load frames."); setLoading(false); } });
    return () => controller.abort();
  }, [predictionId, completed, attempt]);

  const visible = filterPredictionFrames(frames, kind);
  const position = Math.min(index, Math.max(0, visible.length - 1));
  const current = !loading && !error ? visible[position] : undefined;
  const currentKey = current ? JSON.stringify([current.kind, current.name, attempt]) : "";
  const firstThumbnail = Math.floor(position / 12) * 12;

  useEffect(() => {
    if (!playing || visible.length < 2) return;
    const timer = window.setInterval(() => {
      if (!document.hidden) { setIndex((value) => (value + 1) % visible.length); setImageError(""); }
    }, 900);
    return () => window.clearInterval(timer);
  }, [playing, visible.length]);

  function selectFrame(value: number) { setIndex(value); setImageError(""); }
  function selectKind(value: FrameFilter) { setKind(value); selectFrame(0); setPlaying(false); }
  function retry() { setLoading(true); setError(""); setFrames([]); selectFrame(0); setPlaying(false); setAttempt((value) => value + 1); }
  return <section className="prediction-frame-viewer" aria-label={completed ? "Prediction result preview" : "Uploaded TIFF preview"}>
    <div className="module-actions frame-tabs" role="group" aria-label="Frame type">
      {completed && <button type="button" className="button button--secondary" aria-pressed={kind === "all"} onClick={() => selectKind("all")}>All frames ({frames.length})</button>}
      <button type="button" className="button button--secondary" aria-pressed={kind === "input"} onClick={() => selectKind("input")}>Input frames ({filterPredictionFrames(frames, "input").length})</button>
      {completed && <button type="button" className="button button--secondary" aria-pressed={kind === "output"} onClick={() => selectKind("output")}>AI frames ({filterPredictionFrames(frames, "output").length})</button>}
      <span className="module-note" aria-live="polite">{visible.length} frames</span>
    </div>
    {loading && <p role="status">Rendering your TIFF previews…</p>}
    {error && <div className="form-message form-message--error" role="alert"><p>{error}</p><button type="button" className="button button--secondary" onClick={retry}>Retry preview</button></div>}
    {!loading && !error && !current && <p role="status">No {kind === "all" ? "frames" : kind === "input" ? "input frames" : "AI frames"} are available.</p>}
    {current && <>
      <figure className="frame-stage">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img key={currentKey} src={framePreviewUrl(predictionId, current, 1024)} alt={frameKindLabel(current.kind) + " · " + current.name} onError={() => setImageError(currentKey)} onLoad={() => setImageError((value) => value === currentKey ? "" : value)} />
        <figcaption><span className="frame-caption-name"><span className={"frame-kind-badge frame-kind-badge--" + current.kind}>{frameKindLabel(current.kind)}</span><strong>{current.name}</strong></span><span>{position + 1} / {visible.length} · {bytes(current.size)}</span></figcaption>
      </figure>
      {imageError === currentKey && <div className="form-message form-message--error" role="alert"><p>This frame could not be rendered. Try another frame or retry the preview. The original TIFF remains in the download.</p><button type="button" className="button button--secondary" onClick={retry}>Retry preview</button></div>}
      <div className="frame-controls">
        <button type="button" className="button button--secondary" disabled={position === 0} onClick={() => selectFrame(position - 1)}>Previous frame</button>
        <button type="button" className="button button--secondary" disabled={visible.length < 2} onClick={() => setPlaying(!playing)}>{playing ? "Pause preview" : "Play preview"}</button>
        <button type="button" className="button button--secondary" disabled={position >= visible.length - 1} onClick={() => selectFrame(position + 1)}>Next frame</button>
        <label><span>Frame {position + 1} of {visible.length}</span><input aria-label="Choose frame" type="range" min={0} max={Math.max(0, visible.length - 1)} value={position} onChange={(event) => selectFrame(Number(event.target.value))} /></label>
      </div>
      <div className="frame-thumbnails" aria-label="Frame thumbnails">
        {visible.slice(firstThumbnail, firstThumbnail + 12).map((frame, offset) => <button type="button" key={JSON.stringify([frame.kind, frame.name])} aria-label={frameKindLabel(frame.kind) + " · " + frame.name} aria-pressed={position === firstThumbnail + offset} onClick={() => selectFrame(firstThumbnail + offset)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img loading="lazy" src={framePreviewUrl(predictionId, frame, 128)} alt="" /><span className={"frame-kind-badge frame-kind-badge--" + frame.kind}>{frameKindLabel(frame.kind)}</span><span>{frame.name}</span>
        </button>)}
      </div>
      <p className="module-note">TIFF files are shown as display previews. Downloads preserve the original TIFF data.</p>
    </>}
  </section>;
}
