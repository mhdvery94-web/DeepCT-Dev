"use client";

import { useEffect, useState } from "react";
import { asRows, backend, bytes, type Row } from "@/lib/client-api";

export function PredictionFrameViewer({ predictionId, completed }: { predictionId: Row["id"]; completed: boolean }) {
  const [frames, setFrames] = useState<Row[]>([]);
  const [kind, setKind] = useState(completed ? "output" : "input");
  const [index, setIndex] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [error, setError] = useState("");
  const [imageError, setImageError] = useState(false);
  const [loading, setLoading] = useState(true);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    void backend("/predictions/" + predictionId + "/frames", "GET", undefined, controller.signal)
      .then((response) => { if (!controller.signal.aborted) { setFrames(asRows(response.data)); setError(""); setLoading(false); } })
      .catch((reason) => { if (!controller.signal.aborted) { setError(reason instanceof Error ? reason.message : "Unable to load frames."); setLoading(false); } });
    return () => controller.abort();
  }, [predictionId, completed, attempt]);

  const visible = frames.filter((frame) => frame.kind === kind);
  const position = Math.min(index, Math.max(0, visible.length - 1));
  const current = visible[position];
  const firstThumbnail = Math.floor(position / 12) * 12;
  const preview = (frame: Row, size: number) => "/api/backend/predictions/" + predictionId + "/frames/" + encodeURIComponent(String(frame.name)) + "/preview?kind=" + encodeURIComponent(String(frame.kind)) + "&size=" + size;

  useEffect(() => {
    if (!playing || visible.length < 2) return;
    const timer = window.setInterval(() => {
      if (!document.hidden) { setIndex((value) => (value + 1) % visible.length); setImageError(false); }
    }, 900);
    return () => window.clearInterval(timer);
  }, [playing, visible.length]);

  function selectFrame(value: number) { setIndex(value); setImageError(false); }
  return <section className="prediction-frame-viewer" aria-label={completed ? "Prediction result preview" : "Uploaded TIFF preview"}>
    <div className="module-actions frame-tabs" role="group" aria-label="Frame type">
      <button type="button" className="button button--secondary" aria-pressed={kind === "input"} onClick={() => { setKind("input"); selectFrame(0); setPlaying(false); }}>Input frames</button>
      {completed && <button type="button" className="button button--secondary" aria-pressed={kind === "output"} onClick={() => { setKind("output"); selectFrame(0); setPlaying(false); }}>Result frames</button>}
      <span className="module-note">{visible.length} frames</span>
    </div>
    {loading && <p role="status">Rendering your TIFF previews…</p>}
    {error && <div className="form-message form-message--error" role="alert"><p>{error}</p><button type="button" className="button button--secondary" onClick={() => setAttempt(attempt + 1)}>Retry preview</button></div>}
    {!loading && !error && !current && <p role="status">No {kind === "input" ? "input" : "result"} frames are available.</p>}
    {current && <>
      <figure className="frame-stage">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img key={String(current.kind) + String(current.name) + attempt} src={preview(current, 1024)} alt={String(current.name)} onError={() => setImageError(true)} onLoad={() => setImageError(false)} />
        <figcaption><strong>{String(current.name)}</strong><span>{position + 1} / {visible.length} · {bytes(current.size)}</span></figcaption>
      </figure>
      {imageError && <p className="form-message form-message--error" role="alert">This frame could not be rendered. Try another frame or retry the preview. The original TIFF remains in the download.</p>}
      <div className="frame-controls">
        <button type="button" className="button button--secondary" disabled={position === 0} onClick={() => selectFrame(position - 1)}>Previous frame</button>
        <button type="button" className="button button--secondary" disabled={visible.length < 2} onClick={() => setPlaying(!playing)}>{playing ? "Pause preview" : "Play preview"}</button>
        <button type="button" className="button button--secondary" disabled={position >= visible.length - 1} onClick={() => selectFrame(position + 1)}>Next frame</button>
        <label><span>Frame {position + 1} of {visible.length}</span><input aria-label="Choose frame" type="range" min={0} max={Math.max(0, visible.length - 1)} value={position} onChange={(event) => selectFrame(Number(event.target.value))} /></label>
      </div>
      <div className="frame-thumbnails" aria-label="Frame thumbnails">
        {visible.slice(firstThumbnail, firstThumbnail + 12).map((frame, offset) => <button type="button" key={String(frame.kind) + String(frame.name)} aria-pressed={position === firstThumbnail + offset} onClick={() => selectFrame(firstThumbnail + offset)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img loading="lazy" src={preview(frame, 128)} alt="" /><span>{String(frame.name)}</span>
        </button>)}
      </div>
      <p className="module-note">TIFF files are shown as display previews. Downloads preserve the original TIFF data.</p>
    </>}
  </section>;
}
