"use client";

import { useRef, useState } from "react";
import { startPredictionDownload } from "@/lib/prediction-download";

export function PredictionDownload({ path, children, className }: { path: string; children: React.ReactNode; className?: string }) {
  const preparing = useRef(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function download() {
    if (preparing.current) return;
    preparing.current = true; setBusy(true); setError("");
    try { await startPredictionDownload(path); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to start download."); }
    finally { preparing.current = false; setBusy(false); }
  }
  return <span><button type="button" className={className} disabled={busy} aria-busy={busy} onClick={() => void download()}>{busy ? "Preparing download…" : children}</button><span aria-live="polite" role="status">{error}</span></span>;
}
