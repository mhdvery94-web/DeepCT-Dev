export type AiMessage = { id: number; role: "user" | "assistant"; content: string; created_at: string };
export type AiConversation = { id: number; title: string; created_at: string; updated_at: string };
export type AiPagination = { current_page: number; last_page: number; per_page: number; total: number };
export type AiStatus = { mode?: "metadata" | "freeform"; enabled: boolean; model: string; experimental: true; prompt_version: string; limits: { message_characters: number; requests_per_day: number; queue: number; context_tokens: number; output_tokens: number; history_messages: number; history_characters: number; active_requests_per_user: number } };
export type EvidenceFact = { label: string; value: string };
export type EvidenceMetrics = Record<string, number | null>;
export type EvidenceMeasurement = { metrics: EvidenceMetrics; metricStatus: { psnr: string; ssim: string } };
export type EvaluationReport = EvidenceMeasurement & {
  status: "completed" | "no_reference" | "evaluation_failed" | "legacy_unknown";
  method: EvidenceFact[]; reference: { index: number; from: [number, number] } | null;
  model: EvidenceFact[]; baseline: EvidenceMeasurement & { status: string; method: EvidenceFact[] };
  comparison: { status: string; values: EvidenceMetrics };
};
export type AiAnalysisSource = {
  type: "analysis_record"; id: number; status: string;
  input_files_count: number | null; output_files_count: number | null;
  processing_time_seconds: number | null; expired: boolean | null; files_deleted: boolean | null;
  model: EvidenceFact[]; evaluation: EvaluationReport;
};
export type AiDocumentSource = { type: "document"; id: string; version: string; title: string; text: string };
export type AiSource = AiAnalysisSource | AiDocumentSource;
export type AiRequest = { id: number; conversation_id: number; user_message_id: number; analysis_record_id: number | null; status: "queued" | "processing" | "completed" | "failed" | "cancelled"; error_code: string | null; model: string; prompt_version: string; experimental: true; assistant_message: AiMessage | null; sources: unknown[]; metrics: Record<string, number> | null };
export type AiDetail = AiConversation & { messages: AiMessage[]; pagination: AiPagination; request: AiRequest | null };
export type AiSubmission = { content: string; idempotency_key: string; analysis_record_id?: number | null };

/** undefined inherits the conversation; null explicitly clears its analysis. */
export function contextSubmission(content: string, key: string, context: number | null | undefined): AiSubmission {
  return { content, idempotency_key: key, ...(context !== undefined ? { analysis_record_id: context } : {}) };
}
export function contextSelection(value: string): number | null | undefined {
  if (value === "") return null;
  const id = Number(value);
  return Number.isSafeInteger(id) && id > 0 ? id : undefined;
}
export function regenerationSubmission(message: AiMessage, request: AiRequest, key: string): AiSubmission {
  return contextSubmission(message.content, key, request.analysis_record_id ?? null);
}

export const activeRequest = (request: AiRequest | null | undefined) => request?.status === "queued" || request?.status === "processing";
export const requestLabels = { queued: "Dalam antrean", processing: "Sedang diproses", completed: "Selesai", failed: "Gagal", cancelled: "Dibatalkan" };
export function mergeMessages(previous: AiMessage[], incoming: AiMessage[]): AiMessage[] {
  const unique = new Map(previous.map(message => [message.id, message]));
  incoming.forEach(message => unique.set(message.id, message));
  return [...unique.values()].sort((a, b) => a.id - b.id);
}
export function providerMetric(key: string, value: number | null | undefined): string {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return "Tidak tersedia";
  return key.endsWith("_duration") ? `${(value / 1_000_000_000).toFixed(1)} detik` : String(value);
}


const unavailable = "Tidak tersedia";
const object = (v: unknown): Record<string, unknown> => v !== null && typeof v === "object" && !Array.isArray(v) ? v as Record<string, unknown> : {};
const finite = (v: unknown, min = 0, max = Number.MAX_SAFE_INTEGER): number | null => typeof v === "number" && Number.isFinite(v) && v >= min && v <= max ? v : null;
const integer = (v: unknown, min = 0) => typeof v === "number" && Number.isSafeInteger(v) && v >= min ? v : null;
const enumValue = (v: unknown, allowed: string[], fallback: string): string => typeof v === "string" && allowed.includes(v) ? v : fallback;
const safeText = (v: unknown, max: number): string | null => typeof v === "string" && v.length > 0 && v.length <= max && !/[<>\\/\u0000-\u001f]/u.test(v) ? v : null;
// Document prose may contain word separators (Mulai/Start). Keep the stricter
// metadata validator above; path syntax, markup, raw JSON and errors stay out.
function documentProse(value: unknown, max: number): string | null {
  if (typeof value !== "string" || value.length === 0 || value.length > max
    || /[<>{}\\\u0000-\u001f]/u.test(value)
    || /(?:exception|[a-z]*error:|stack trace)/i.test(value)) return null;
  const prosePair = /^[('"“‘]*[\p{L}\p{N}]+\/[\p{L}\p{N}]+[)'"”’.,;:!?]*$/u;
  return value.split(/\s+/u).every(token => !token.includes("/") || prosePair.test(token)) ? value : null;
}
const metricLabels: Record<string, string> = { mae: "MAE", rmse: "RMSE", psnr: "PSNR (dB)", ssim: "SSIM", pixels: "Jumlah piksel", reference_min: "Minimum referensi", reference_max: "Maksimum referensi" };
function measurement(raw: unknown): EvidenceMeasurement {
  const v = object(raw), m = object(v.metrics), status = object(v.metric_status);
  return { metrics: Object.fromEntries(Object.keys(metricLabels).map(key => [key, finite(m[key], key === "ssim" ? -1 : key === "pixels" ? 1 : 0, key === "ssim" ? 1 : key === "psnr" ? 1000 : key === "pixels" ? Number.MAX_SAFE_INTEGER : 65535)])), metricStatus: {
    psnr: enumValue(status.psnr, ["available", "infinite", "unavailable"], "unknown"),
    ssim: enumValue(status.ssim, ["available", "image_too_small", "unavailable"], "unknown"),
  } };
}
function modelFacts(raw: unknown): EvidenceFact[] {
  const v = object(raw);
  if (v.provenance === "historical_model_snapshot_unavailable") return [{ label: "Model CT", value: "Versi historis / provenans model tidak tersedia" }];
  const facts: EvidenceFact[] = [];
  for (const [key, label, limit] of [["name", "Model CT", 120], ["version", "Versi model", 64], ["slug", "Slug model", 120], ["model_id", "Identitas model", 120]] as const) {
    const text = safeText(v[key], limit);
    if (text && /^[\p{L}\p{N} ._()+-]+$/u.test(text)) facts.push({ label, value: text });
  }
  const id = integer(v.id, 1); if (id !== null) facts.push({ label: "ID model", value: String(id) });
  const provenance = enumValue(v.provenance, ["managed_manifest_sha256", "legacy_registry_metadata"], "");
  if (provenance) facts.push({ label: "Provenans model", value: provenance });
  if (typeof v.sha256 === "string" && /^[a-f0-9]{64}$/.test(v.sha256)) facts.push({ label: "SHA256", value: v.sha256 });
  return facts;
}
function methodFacts(raw: unknown): EvidenceFact[] {
  const v = object(raw), s = object(v.ssim), result: EvidenceFact[] = [];
  for (const [key, expected, label] of [["sample_domain", "raw_uint16", "Domain sampel"], ["data_range", 65535, "Rentang data"], ["mae_decimals", 3, "Desimal MAE"], ["rmse_decimals", 3, "Desimal RMSE"], ["psnr_decimals", 2, "Desimal PSNR"], ["baseline", "linear_midpoint", "Metode baseline"], ["midpoint_rounding", "half_up", "Pembulatan midpoint"]] as const) {
    if (v[key] === expected) result.push({ label, value: String(expected) });
  }
  for (const [key, expected, label] of [["window_size", 7, "Jendela SSIM"], ["weighting", "uniform", "Bobot SSIM"], ["boundary", "valid", "Batas SSIM"], ["covariance", "sample", "Kovarians SSIM"], ["k1", 0.01, "K1 SSIM"], ["k2", 0.03, "K2 SSIM"]] as const) {
    if (s[key] === expected) result.push({ label, value: String(expected) });
  }
  return result;
}
function evaluationReport(raw: unknown, legacyMetrics: unknown): EvaluationReport {
  const v = object(raw), baseline = object(v.baseline), comparison = object(v.comparison), r = object(v.reference);
  const valid = v.schema_version === 1;
  const status = valid ? enumValue(v.evaluation_status, ["completed", "no_reference", "evaluation_failed"], "legacy_unknown") : "legacy_unknown";
  const index = integer(r.index), from = r.from;
  const reference = valid && r.source === "uploaded_midpoint" && index !== null && Array.isArray(from) && from.length === 2 && integer(from[0]) !== null && integer(from[1]) !== null && from[0] < index && from[1] > index && index - from[0] === from[1] - index ? { index, from: [from[0], from[1]] as [number, number] } : null;
  const completed = valid && comparison.status === "completed" && comparison.precision === "recorded_precision";
  return { ...measurement(valid ? v : { metrics: legacyMetrics }), status: status as EvaluationReport["status"], reference,
    method: valid ? methodFacts(v.method) : [], model: valid ? modelFacts(v.model) : [],
    baseline: { ...measurement(valid ? baseline : {}), status: valid ? enumValue(baseline.status, ["completed", "baseline_failed"], "unavailable") : "unavailable", method: valid ? methodFacts(baseline.method) : [] },
    comparison: { status: completed ? "completed" : "unavailable", values: Object.fromEntries(["mae_reduction", "rmse_reduction", "psnr_gain_db", "ssim_gain"].map(key => [key, completed ? finite(comparison[key], -65535, 65535) : null])) },
  };
}
/** Copy only the public contract; unknown fields and free-form error/provenance arrays never reach the UI. */
export function parseAiSources(raw: unknown): AiSource[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item): AiSource[] => {
    const v = object(item);
    if (v.type === "document") {
      const id = safeText(v.id, 80), version = safeText(v.version, 40), title = documentProse(v.title, 120), text = documentProse(v.text, 900);
      return id && /^deepct-sop-[a-z-]+$/.test(id) && version && title && text ? [{ type: "document", id, version, title, text }] : [];
    }
    const id = integer(v.id, 1);
    if (v.type !== "analysis_record" || id === null) return [];
    return [{ type: "analysis_record", id, status: enumValue(v.status, ["uploaded", "pending", "processing", "completed", "failed"], "unknown"),
      input_files_count: integer(v.input_files_count), output_files_count: integer(v.output_files_count), processing_time_seconds: finite(v.processing_time_seconds),
      expired: typeof v.expired === "boolean" ? v.expired : null, files_deleted: typeof v.files_deleted === "boolean" ? v.files_deleted : null,
      model: modelFacts(v.model), evaluation: evaluationReport(v.evaluation, v.metrics) }];
  });
}
export const evaluationLabels: Record<EvaluationReport["status"], string> = { completed: "Evaluasi selesai", no_reference: "Tidak ada referensi unggahan", evaluation_failed: "Pengukuran gagal", legacy_unknown: "Evaluasi historis tidak diketahui" };
export function measurementFacts(report: EvidenceMeasurement): EvidenceFact[] {
  return Object.entries(metricLabels).map(([key, label]) => ({ label, value: key === "psnr" && report.metricStatus.psnr === "infinite" ? "Tak terhingga (galat tepat nol)" : key === "ssim" && report.metricStatus.ssim === "image_too_small" ? "Tidak tersedia · Citra terlalu kecil" : report.metrics[key] == null ? unavailable : String(report.metrics[key]) }));
}
export function analysisFacts(source: AiAnalysisSource): EvidenceFact[] {
  const e = source.evaluation;
  const yesNo = (v: boolean | null) => v === null ? unavailable : v ? "Ya" : "Tidak";
  return [
    { label: "Status evaluasi", value: evaluationLabels[e.status] },
    { label: "Referensi", value: e.reference ? `Midpoint unggahan #${e.reference.index} · ${e.reference.from[0]} → ${e.reference.from[1]}` : unavailable },
    ...(e.model.length ? e.model : source.model.length ? source.model : [{ label: "Model CT", value: unavailable }]),
    { label: "Berkas input / hasil", value: `${source.input_files_count ?? unavailable} / ${source.output_files_count ?? unavailable}` },
    { label: "Waktu analisis", value: source.processing_time_seconds === null ? unavailable : `${source.processing_time_seconds} detik` },
    { label: "Kedaluwarsa / dihapus", value: `${yesNo(source.expired)} / ${yesNo(source.files_deleted)}` },
  ];
}
export function comparisonFacts(report: EvaluationReport): EvidenceFact[] {
  return Object.entries({ mae_reduction: "Pengurangan MAE", rmse_reduction: "Pengurangan RMSE", psnr_gain_db: "Kenaikan PSNR (dB)", ssim_gain: "Kenaikan SSIM" }).map(([key, label]) => ({ label, value: report.comparison.values[key] == null ? unavailable : String(report.comparison.values[key]) }));
}

export function assistantErrorMessage(value: unknown): string {
  const text = safeText(value, 240);
  return text && !/(?:exception|[a-z]*error:|stack trace|[{}])/i.test(text) ? text : "Permintaan tidak dapat diselesaikan. Coba lagi.";
}
export function requestFailureLabel(code: unknown): string {
  const labels: Record<string, string> = { provider_timeout: "Batas waktu jawaban terlampaui (provider_timeout)", worker_timeout: "Batas waktu pemrosesan terlampaui (worker_timeout)", context_unavailable: "Konteks tidak tersedia (context_unavailable)", generation_busy: "Pemrosesan sedang sibuk (generation_busy)", access_revoked: "Akses tidak tersedia (access_revoked)" };
  return typeof code === "string" && Object.hasOwn(labels, code) ? labels[code] : "Jawaban gagal dibuat";
}
export const analysisStatusLabels: Record<string, string> = { uploaded: "Unggahan siap ditinjau", pending: "Dalam antrean", processing: "Sedang diproses", completed: "Selesai", failed: "Gagal", unknown: "Status tidak diketahui" };
