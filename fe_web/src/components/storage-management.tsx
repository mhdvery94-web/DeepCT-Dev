"use client";

import { useCallback, useEffect, useState } from "react";
import { asRow, asRows, backend, bytes, display, type Row } from "@/lib/client-api";
import { Modal } from "@/components/modal";

export function StorageManagement() {
  const [report, setReport] = useState<Row>();
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState<{ path: string; prediction?: Row }>();
  const [confirmed, setConfirmed] = useState(false);
  const refresh = useCallback(async () => {
    try { setReport(asRow((await backend("/admin/storage")).data)); setError(""); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to read storage."); }
  }, []);
  useEffect(() => { void Promise.resolve().then(refresh); }, [refresh]);
  function requestCleanup(path: string, prediction?: Row) {
    setPending({ path, prediction }); setConfirmed(false);
  }
  async function cleanup() {
    if (!pending || !confirmed) return;
    setBusy(true); setError(""); setMessage("");
    try { const result = await backend(pending.path, "POST", {}); setMessage(result.message ?? "Cleanup completed."); setPending(undefined); await refresh(); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Cleanup failed."); }
    finally { setBusy(false); }
  }
  const total = Number(report?.total_bytes); const used = Number(report?.used_bytes);
  const percent = total > 0 ? Math.min(100, Math.round(used / total * 100)) : 0;
  return <div className="data-module" aria-busy={busy}>
    <div className="module-toolbar"><button className="button button--secondary" disabled={busy} onClick={() => void refresh()}>Refresh storage</button><button className="button button--primary" disabled={busy || !report || report.mounted !== true} onClick={() => requestCleanup("/admin/storage/cleanup")}>Clean expired application files</button></div>
    {error && <p className="form-message form-message--error" role="alert">{error}</p>}
    {message && <p className="form-message form-message--success" role="status">{message}</p>}
    {report && <>
      {report.mounted !== true && <p className="form-message form-message--error">Application storage is not mounted. Cleanup is unavailable.</p>}
      <section className="storage-overview" aria-label="Disk space"><article><span>Free space</span><strong>{bytes(report.free_bytes)}</strong></article><article><span>Total volume</span><strong>{bytes(report.total_bytes)}</strong></article><article><span>Volume used</span><strong>{percent}%</strong><progress max={100} value={percent} /></article></section>
      <section className="module-panel"><h2>What cleanup removes</h2><p>The disk totals above cover the whole Raspberry Pi volume. These buttons only clean DeepCT prediction files and its temporary upload/download files.</p>
        <ol className="storage-instructions"><li><strong>Download results first.</strong> Full TIFF files cannot be restored after cleanup.</li><li><strong>Use expired-file cleanup for routine maintenance.</strong> It applies retention rules to expired predictions and stale temporary files. Queued and processing predictions are kept.</li><li><strong>Use the job button for immediate cleanup.</strong> It removes input TIFFs, result TIFFs and cached previews from that completed or failed job, even before expiry.</li></ol>
        <p><strong>Kept:</strong> accounts, database records, research history, retained evidence thumbnails, news/media, backups, operating-system files, and model weights on the TUF laptop.</p>
        <div className="storage-breakdown">{Object.entries(asRow(report.breakdown)).filter(([key]) => key !== "id").map(([key, value]) => <article key={key}><span>{key.replaceAll("_", " ")}</span><strong>{bytes(value)}</strong></article>)}</div>
      </section>
      <section className="module-panel"><h2>Finished predictions</h2><p>Select the exact dataset and researcher before removing its files. This does not delete the prediction history.</p><div className="module-table-wrap"><table className="module-table"><thead><tr><th>Dataset</th><th>Researcher</th><th>Status</th><th>Application files</th><th>Actions</th></tr></thead><tbody>{asRows(report.cleanup_candidates).map((row) => <tr key={row.id}><td>{display(row.file_name || row.job_id)}</td><td>{display(row.owner)}</td><td>{display(row.status)}</td><td>{bytes(row.bytes)}</td><td><button className="button button--secondary" disabled={busy || report.mounted !== true} onClick={() => requestCleanup("/admin/storage/predictions/" + row.id + "/cleanup", row)}>Review file cleanup</button></td></tr>)}{!asRows(report.cleanup_candidates).length && <tr><td colSpan={5}>No finished predictions need cleanup.</td></tr>}</tbody></table></div><p className="module-note">The oldest 100 eligible jobs are listed. Refresh after cleanup to see the next jobs.</p></section>
    </>}
    {pending && <Modal labelledBy="cleanup-title" onClose={() => setPending(undefined)} busy={busy}>
      <h2 id="cleanup-title">{pending.prediction ? "Remove this prediction’s files?" : "Clean expired DeepCT files?"}</h2>
      {pending.prediction ? <dl className="record-details"><div><dt>Dataset</dt><dd>{display(pending.prediction.file_name || pending.prediction.job_id)}</dd></div><div><dt>Researcher</dt><dd>{display(pending.prediction.owner)}</dd></div><div><dt>Files to remove</dt><dd>{bytes(pending.prediction.bytes)} · input TIFFs, result TIFFs and cached previews</dd></div></dl> : <p>Remove expired prediction files, abandoned upload sessions and stale download ZIPs according to retention rules. Active predictions remain available.</p>}
      <p>Full files are permanently removed. History, retained evidence, accounts, database, publications, backups and files outside DeepCT prediction/temporary storage are preserved.</p>
      <label className="cleanup-confirmation"><input type="checkbox" checked={confirmed} disabled={busy} onChange={(event) => setConfirmed(event.target.checked)} /><span>I have saved any files I need and understand that this cleanup cannot be undone.</span></label>
      {error && <p className="form-message form-message--error" role="alert">{error}</p>}
      <div className="module-actions"><button type="button" className="button button--primary" disabled={!confirmed || busy} onClick={() => void cleanup()}>{busy ? "Cleaning…" : pending.prediction ? "Delete this job’s files" : "Clean expired files"}</button><button type="button" className="button button--secondary" disabled={busy} onClick={() => setPending(undefined)}>Cancel</button></div>
    </Modal>}
  </div>;
}
