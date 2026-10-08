"use client";

import { useCallback, useEffect, useState } from "react";
import { asRow, asRows, backend, bytes, display, type Row } from "@/lib/client-api";

export function StorageManagement() {
  const [report, setReport] = useState<Row>();
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const refresh = useCallback(async () => {
    try { setReport(asRow((await backend("/admin/storage")).data)); setError(""); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to read storage."); }
  }, []);
  useEffect(() => { void Promise.resolve().then(refresh); }, [refresh]);
  async function cleanup(path: string, confirmation: string) {
    if (!window.confirm(confirmation)) return;
    setBusy(true); setError(""); setMessage("");
    try { const result = await backend(path, "POST", {}); setMessage(result.message ?? "Cleanup completed."); await refresh(); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Cleanup failed."); }
    finally { setBusy(false); }
  }
  const total = Number(report?.total_bytes); const used = Number(report?.used_bytes);
  const percent = total > 0 ? Math.min(100, Math.round(used / total * 100)) : 0;
  return <div className="data-module" aria-busy={busy}>
    <div className="module-toolbar"><button className="button button--secondary" disabled={busy} onClick={() => void refresh()}>Refresh storage</button><button className="button button--primary" disabled={busy || !report || report.mounted !== true} onClick={() => void cleanup("/admin/storage/cleanup", "Clean expired application files and abandoned uploads using the retention rules?")}>Clean expired files</button></div>
    {error && <p className="form-message form-message--error" role="alert">{error}</p>}
    {message && <p className="form-message form-message--success" role="status">{message}</p>}
    {report && <>
      {report.mounted !== true && <p className="form-message form-message--error">Application storage is not mounted. Cleanup is unavailable.</p>}
      <section className="storage-overview" aria-label="Disk space"><article><span>Free space</span><strong>{bytes(report.free_bytes)}</strong></article><article><span>Total volume</span><strong>{bytes(report.total_bytes)}</strong></article><article><span>Volume used</span><strong>{percent}%</strong><progress max={100} value={percent} /></article></section>
      <section className="module-panel"><h2>Application storage</h2><p>The volume totals include other software on the Raspberry Pi. Cleanup acts only on DeepCT application files. Prediction records and evidence remain available.</p><div className="storage-breakdown">{Object.entries(asRow(report.breakdown)).filter(([key]) => key !== "id").map(([key, value]) => <article key={key}><span>{key.replaceAll("_", " ")}</span><strong>{bytes(value)}</strong></article>)}</div></section>
      <section className="module-panel"><h2>Finished predictions</h2><p>Remove files from a completed or failed job to free space immediately. Download any results you still need first.</p><div className="module-table-wrap"><table className="module-table"><thead><tr><th>Dataset</th><th>Researcher</th><th>Status</th><th>Application files</th><th>Actions</th></tr></thead><tbody>{asRows(report.cleanup_candidates).map((row) => <tr key={row.id}><td>{display(row.file_name || row.job_id)}</td><td>{display(row.owner)}</td><td>{display(row.status)}</td><td>{bytes(row.bytes)}</td><td><button className="button button--secondary" disabled={busy || report.mounted !== true} onClick={() => void cleanup(`/admin/storage/predictions/${row.id}/cleanup`, `Permanently remove application files for ${row.file_name || row.job_id}? Its history and evidence will remain.`)}>Remove files</button></td></tr>)}{!asRows(report.cleanup_candidates).length && <tr><td colSpan={5}>No finished predictions need cleanup.</td></tr>}</tbody></table></div><p className="module-note">The oldest 100 eligible jobs are listed. Refresh after cleanup to see the next jobs.</p></section>
    </>}
  </div>;
}
