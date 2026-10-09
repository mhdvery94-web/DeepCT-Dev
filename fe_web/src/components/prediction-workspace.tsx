"use client";

import { useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import { PredictionFrameViewer } from "@/components/prediction-frame-viewer";
import { asRow, asRows, backend, bytes, display, uploadArchive, type ApiResult, type Row } from "@/lib/client-api";
import { preparePredictionArchive, validatePredictionFiles } from "@/lib/prediction-files";

const statusLabels: Record<string, string> = { uploaded: "Ready for review", pending: "Queued", processing: "Processing", completed: "Completed", failed: "Failed" };
const activeStatuses = ["pending", "processing"];

export function PredictionWorkspace() {
  const [result, setResult] = useState<ApiResult>();
  const [models, setModels] = useState<Row[]>([]);
  const [files, setFiles] = useState<File[]>([]);
  const [selected, setSelected] = useState<Row>();
  const [selectedId, setSelectedId] = useState<Row["id"]>();
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadPhase, setUploadPhase] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [modelError, setModelError] = useState("");
  const uploadController = useRef<AbortController | null>(null);
  const review = useRef<HTMLElement>(null);
  const selection = useRef<Row["id"] | undefined>(undefined);
  const refreshSequence = useRef(0);

  const loadModels = useCallback(async (signal?: AbortSignal) => {
    try { setModels(asRows((await backend("/me/models", "GET", undefined, signal)).data)); setModelError(""); }
    catch (reason) { if (!signal?.aborted) setModelError(reason instanceof Error ? reason.message : "Unable to load models."); }
  }, []);
  const refresh = useCallback(async (signal?: AbortSignal) => {
    const sequence = ++refreshSequence.current;
    try {
      const history = backend("/predictions?" + new URLSearchParams({ page: String(page), per_page: "15", ...(status ? { status } : {}) }), "GET", undefined, signal);
      const detail = selectedId === undefined ? Promise.resolve(undefined) : backend("/predictions/" + selectedId, "GET", undefined, signal);
      const [list, current] = await Promise.all([history, detail]);
      if (signal?.aborted || sequence !== refreshSequence.current) return;
      setResult(list);
      if (current && selection.current === selectedId) setSelected((previous) => ({ ...previous, ...asRow(current.data) }));
      setLoading(false);
    } catch (reason) { if (!signal?.aborted) { setError(reason instanceof Error ? reason.message : "Unable to refresh predictions."); setLoading(false); } }
  }, [page, status, selectedId]);

  useEffect(() => {
    const controller = new AbortController();
    void Promise.resolve().then(() => loadModels(controller.signal));
    return () => controller.abort();
  }, [loadModels]);
  const hasActiveJobs = activeStatuses.includes(String(selected?.status)) || asRows(result?.data).some((row) => activeStatuses.includes(String(row.status)));
  useEffect(() => {
    const controller = new AbortController();
    let running = false;
    const poll = async () => {
      if (running || controller.signal.aborted) return;
      running = true;
      try { await refresh(controller.signal); } finally { running = false; }
    };
    void poll();
    const timer = window.setInterval(() => { if (!document.hidden) void poll(); }, hasActiveJobs ? 3000 : 15000);
    return () => { controller.abort(); window.clearInterval(timer); };
  }, [refresh, hasActiveJobs]);
  useEffect(() => () => uploadController.current?.abort(), []);

  function open(row: Row) {
    selection.current = row.id;
    setSelected(row); setSelectedId(row.id);
    void backend("/predictions/" + row.id).then((response) => {
      if (selection.current === row.id) setSelected((previous) => ({ ...previous, ...asRow(response.data) }));
    }).catch((reason) => { if (selection.current === row.id) setError(reason instanceof Error ? reason.message : "Unable to load prediction."); });
    window.requestAnimationFrame(() => review.current?.scrollIntoView({ block: "start", behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth" }));
  }
  async function upload(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const modelId = Number(new FormData(form).get("model_id"));
    const controller = new AbortController();
    try { validatePredictionFiles(files); } catch (reason) { setError((reason as Error).message); return; }
    if (!modelId) { setError("Choose an available model first."); return; }
    uploadController.current = controller; setBusy(true); setUploading(true); setError(""); setNotice(""); setUploadProgress(0);
    try {
      setUploadPhase("Preparing files");
      const archive = await preparePredictionArchive(files, setUploadProgress, controller.signal);
      setUploadPhase("Uploading"); setUploadProgress(0);
      const response = await uploadArchive(archive, { purpose: "prediction", model_id: modelId }, (percent) => { setUploadProgress(percent); if (percent === 100) setUploadPhase("Validating uploaded frames"); }, controller.signal);
      const row = { ...asRow(response.data), file_name: archive.name, model: models.find((model) => Number(model.id) === modelId) };
      setPage(1); setStatus(""); open(row); setFiles([]); form.reset();
      setNotice("Upload complete. Review the input frames below, then select Start analysis.");
    } catch (reason) {
      setError(controller.signal.aborted ? "Upload paused. Select the same files and upload again to resume." : reason instanceof Error ? reason.message : "Upload failed.");
    } finally { setBusy(false); setUploading(false); uploadController.current = null; }
  }
  async function start(row: Row) {
    setBusy(true); setError(""); setNotice("");
    try {
      const response = await backend("/predictions/" + row.id + "/start", "POST", {});
      const updated = asRow((await backend("/predictions/" + row.id)).data);
      open({ ...row, ...updated }); setNotice(response.message ?? "Analysis added to the queue.");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to start analysis."); }
    finally { setBusy(false); }
  }
  async function remove(row: Row) {
    if (!window.confirm("Permanently delete this prediction and its application files? Download any results you still need first.")) return;
    setBusy(true); setError(""); setNotice("");
    try {
      await backend("/predictions/" + row.id, "DELETE");
      if (selectedId === row.id) { selection.current = undefined; setSelectedId(undefined); setSelected(undefined); }
      setResult((previous) => previous ? { ...previous, data: asRows(previous.data).filter((item) => item.id !== row.id) } : previous);
      setNotice("Prediction deleted.");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to delete prediction."); }
    finally { setBusy(false); }
  }
  return <div className="data-module prediction-workspace" aria-busy={loading || busy}>
    {error && <p className="form-message form-message--error" role="alert">{error}</p>}
    {notice && <p className="form-message form-message--success" role="status">{notice}</p>}
    <section className="module-panel">
      <h2>Upload CT frames</h2>
      <p>Choose one ZIP archive or select multiple numbered .tif / .tiff frames at once. Each frame may be up to 50 MB; the archive may be up to 2 GB.</p>
      <form className="module-form" onSubmit={upload}>
        <label><span>Available model</span><select name="model_id" required defaultValue="" disabled={busy}><option value="" disabled>Select a model</option>{models.map((model) => <option key={model.id} value={model.id} disabled={model.is_available === false}>{display(model.name)} · {display(model.version)} · {display(model.status)}</option>)}</select></label>
        {modelError && <p role="alert" className="form-message form-message--error">{modelError}</p>}
        {!models.length && !modelError && <p className="module-note">No models are available yet. Contact your administrator or check availability again.</p>}
        <label><span>ZIP archive or TIFF frames</span><input name="frames" type="file" multiple required disabled={busy} onChange={(event) => {
          const picked = Array.from(event.target.files ?? []);
          try { validatePredictionFiles(picked); setFiles(picked); setError(""); }
          catch (reason) { setFiles([]); setError((reason as Error).message); event.target.value = ""; }
        }} /></label>
        {files.length > 0 && <p className="module-note" role="status">{files.length === 1 ? files[0].name : files.length + " TIFF frames selected"} · {bytes(files.reduce((sum, file) => sum + file.size, 0))}</p>}
        {uploading && <div className="prediction-upload-progress" role="status"><span>{uploadPhase} · {uploadProgress}%</span><progress aria-label={uploadPhase} value={uploadPhase === "Validating uploaded frames" ? undefined : uploadProgress} max={100} /></div>}
        <div className="module-actions"><button className="button button--primary" disabled={busy || !files.length || !models.length}>{uploading ? uploadPhase + "…" : "Upload and preview"}</button><button type="button" className="button button--secondary" disabled={busy} onClick={() => void loadModels()}>Refresh models</button>{uploading && <button type="button" className="button button--secondary" onClick={() => uploadController.current?.abort()}>Pause upload</button>}</div>
      </form>
    </section>
    {selected && <section ref={review} className="module-panel prediction-review" aria-labelledby="prediction-review-title">
      <div className="module-actions"><h2 id="prediction-review-title">{selected.status === "completed" ? "Prediction results" : selected.status === "uploaded" ? "Review uploaded frames" : "Analysis progress"}</h2><button type="button" className="button button--secondary" disabled={busy} onClick={() => { selection.current = undefined; setSelected(undefined); setSelectedId(undefined); }}>Close preview</button></div>
      <p>{display(selected.file_name || selected.job_id)} · {display(asRow(selected.model).name)} · {display(selected.input_files_count)} input frames</p>
      <PredictionProgress prediction={selected} />
      {selected.status === "uploaded" && <div className="module-actions"><button type="button" className="button button--primary" disabled={busy || !hasFiles(selected)} onClick={() => void start(selected)}>{busy ? "Starting…" : "Start analysis"}</button><p className="module-note">Uploading does not start processing. Start only after reviewing your input.</p></div>}
      {selected.status === "completed" && hasFiles(selected) && <ResultDownloads prediction={selected} />}
      {hasFiles(selected) && ["uploaded", "completed"].includes(String(selected.status)) && <PredictionFrameViewer key={String(selected.id) + String(selected.status)} predictionId={selected.id} completed={selected.status === "completed"} />}
      {!hasFiles(selected) && <p className="module-note">The full input and result files are no longer available. Retained evidence and history are shown below.</p>}
      {!hasFiles(selected) && Array.isArray(selected.evidence) && <div className="frame-gallery">{selected.evidence.map((name) => <figure key={String(name)}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img loading="lazy" alt={String(name)} src={"/api/backend/predictions/" + selected.id + "/evidence/" + encodeURIComponent(String(name))} /><figcaption>{String(name)}</figcaption>
      </figure>)}</div>}
      {Boolean(selected.validation || selected.frame_provenance) && <details className="prediction-metadata"><summary>Research metrics and frame provenance</summary>{Boolean(selected.validation) && <><h3>Validation</h3><pre>{JSON.stringify(selected.validation, null, 2)}</pre></>}{Boolean(selected.frame_provenance) && <><h3>Frame provenance</h3><pre>{JSON.stringify(selected.frame_provenance, null, 2)}</pre></>}</details>}
    </section>}
    <section aria-labelledby="prediction-history-title"><div className="module-toolbar"><h2 id="prediction-history-title">Prediction history</h2><select aria-label="Filter predictions by status" value={status} onChange={(event) => { setStatus(event.target.value); setPage(1); }}><option value="">All statuses</option>{Object.entries(statusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select><button type="button" className="button button--secondary" disabled={busy} onClick={() => { setError(""); void refresh(); }}>Refresh predictions</button></div>
      {typeof result?.meta?.queue_message === "string" && <p className="module-note" role="status">{result.meta.queue_message}</p>}
      <div className="module-table-wrap"><table className="module-table"><thead><tr><th>Dataset / model</th><th>Status</th><th>Frames</th><th>Actions</th></tr></thead><tbody>
        {asRows(result?.data).map((row) => <tr key={row.id}><td><strong>{display(row.file_name || row.job_id)}</strong><br />{display(asRow(row.model).name)}</td><td><span className={"prediction-status prediction-status--" + row.status}>{statusLabels[String(row.status)] ?? display(row.status)}</span>{row.status === "pending" && <p>Queue position: {row.queue_position == null ? "waiting for a slot" : display(row.queue_position)}</p>}{row.status === "processing" && <p role="status">Analysis in progress…</p>}</td><td>{display(row.input_files_count)} input / {Number(row.output_files_count) || 0} result</td><td><div className="row-actions"><button type="button" disabled={busy} onClick={() => open(row)}>{row.status === "completed" ? "View results" : "Preview / progress"}</button>{row.status === "uploaded" && <button type="button" disabled={busy || !hasFiles(row)} onClick={() => void start(row)}>Start analysis</button>}{row.status === "completed" && hasFiles(row) && <a href={"/api/backend/predictions/" + row.id + "/download/results"}>Download results</a>}{!activeStatuses.includes(String(row.status)) && <button type="button" className="danger-action" disabled={busy} onClick={() => void remove(row)}>Delete</button>}</div></td></tr>)}
        {!asRows(result?.data).length && <tr><td colSpan={4}>{loading ? "Loading predictions…" : "No predictions found."}</td></tr>}
      </tbody></table></div>
      {result?.pagination && <div className="module-pagination"><span>{result.pagination.total} predictions · page {result.pagination.current_page} / {result.pagination.last_page}</span><button type="button" className="button button--secondary" disabled={busy || page <= 1} onClick={() => setPage(page - 1)}>Previous page</button><button type="button" className="button button--secondary" disabled={busy || page >= result.pagination.last_page} onClick={() => setPage(page + 1)}>Next page</button></div>}
    </section>
  </div>;
}

function hasFiles(prediction: Row): boolean {
  return !prediction.files_deleted_at && (!prediction.expires_at || Date.parse(String(prediction.expires_at)) > Date.now());
}

function ResultDownloads({ prediction }: { prediction: Row }) {
  return <div className="module-actions prediction-downloads"><a className="button button--primary" href={"/api/backend/predictions/" + prediction.id + "/download/results"}>Download results</a><a className="button button--secondary" href={"/api/backend/predictions/" + prediction.id + "/download/complete"}>Download complete archive</a></div>;
}

function PredictionProgress({ prediction }: { prediction: Row }) {
  const status = String(prediction.status);
  const stage = ["uploaded", "pending", "processing", "completed"].indexOf(status);
  return <div className="prediction-progress" role="status" aria-live="polite">
    <ol className="prediction-steps" aria-label="Analysis stages">{["Uploaded / preview", "Queued", "Processing", "Completed"].map((label, index) => <li key={label} className={stage >= index ? "is-reached" : ""} aria-current={stage === index ? "step" : undefined}><span>{stage > index ? "✓" : index + 1}</span>{label}</li>)}</ol>
    {status === "pending" && <p><strong>{prediction.queue_position == null ? "Waiting for a queue slot." : "Queue position: " + prediction.queue_position + "."}</strong>{prediction.estimated_wait_minutes != null ? " Estimated wait: about " + prediction.estimated_wait_minutes + " minutes." : ""}</p>}
    {status === "pending" && typeof prediction.queue_stalled_message === "string" && <p className="module-note">{prediction.queue_stalled_message}</p>}
    {status === "processing" && <><p>The model is processing your frames. This view updates automatically.</p><progress aria-label="Analysis processing" /></>}
    {status === "completed" && <p className="form-message form-message--success">Analysis completed · {display(prediction.output_files_count)} result frames{prediction.processing_time ? " · " + prediction.processing_time : ""}. Your result preview is below.</p>}
    {status === "failed" && <p className="form-message form-message--error" role="alert">Analysis failed. {display(prediction.error_message || "Contact your administrator with this job ID.")}</p>}
  </div>;
}
