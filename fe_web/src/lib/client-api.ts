export type Row = { id: number | string; [key: string]: unknown };
export type ApiResult = {
  success: boolean; message?: string; data: unknown; default_password?: string;
  pagination?: { current_page: number; last_page: number; total: number };
  meta?: Record<string, unknown>; dispatch_message?: string;
};

export async function backend(path: string, method = "GET", body?: FormData | Record<string, unknown>, signal?: AbortSignal): Promise<ApiResult> {
  const multipart = body instanceof FormData;
  const transportMethod = multipart && method !== "POST" && method !== "GET" ? "POST" : method;
  if (multipart && transportMethod !== method) body.set("_method", method);
  const response = await fetch(`/api/backend${path}`, {
    method: transportMethod, signal, cache: "no-store", headers: { Accept: "application/json", ...(!multipart && body ? { "Content-Type": "application/json" } : {}) },
    body: body ? multipart ? body : JSON.stringify(body) : undefined,
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok || payload?.success === false) {
    const validation = payload?.errors ? Object.values(payload.errors).flat().find((value) => typeof value === "string") : undefined;
    throw new Error(String(validation ?? payload?.message ?? `Request failed (${response.status}).`));
  }
  return payload as ApiResult;
}

export function asRow(value: unknown): Row {
  return value && typeof value === "object" ? value as Row : { id: "" };
}
export function asRows(value: unknown): Row[] { return Array.isArray(value) ? value.map(asRow) : []; }
export function display(value: unknown): string {
  if (value == null) return "—";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  if (typeof value === "object") return Object.entries(value).map(([key, item]) => `${key.replaceAll("_", " ")}: ${display(item)}`).join(" · ");
  return String(value);
}
export function bytes(value: unknown): string {
  if (typeof value !== "number") return "—";
  const unit = Math.min(4, Math.floor(Math.log(Math.max(1, value)) / Math.log(1024)));
  return `${(value / 1024 ** unit).toFixed(unit ? 1 : 0)} ${["B", "KB", "MB", "GB", "TB"][unit]}`;
}

/** Vercel caps request bodies at 4.5 MB. Bound each part and resume by offset. */
export async function uploadArchive(file: File, fields: Record<string, unknown>, progress: (value: number) => void, signal?: AbortSignal): Promise<ApiResult> {
  if (!file.size) throw new Error("The selected file is empty.");
  const session = await fetch("/api/auth/session", { signal }).then((response) => response.json());
  if (!session.data?.user?.id) throw new Error("Please sign in again.");
  const key = `deepct-upload:${session.data.user.id}:${JSON.stringify(fields)}:${file.name}:${file.size}:${file.lastModified}`;
  const saved = sessionStorage.getItem(key);
  let info: Row | undefined;
  if (saved) {
    try { info = asRow((await backend(`/predictions/uploads/${encodeURIComponent(saved)}`, "GET", undefined, signal)).data); }
    catch (error) { if (signal?.aborted) throw error; sessionStorage.removeItem(key); }
  }
  if (!info) info = asRow((await backend("/predictions/uploads", "POST", { ...fields, filename: file.name, total_size: file.size }, signal)).data);
  const uploadId = String(info.upload_id);
  sessionStorage.setItem(key, uploadId);
  const chunkSize = Math.min(Number(info.chunk_size) || 3 * 1024 * 1024, 3 * 1024 * 1024);
  let offset = Number(info.received) || 0;
  while (offset < file.size) {
    const data = new FormData(); data.set("offset", String(offset));
    data.set("chunk", file.slice(offset, offset + chunkSize), "chunk.bin");
    const result = await backend(`/predictions/uploads/${uploadId}`, "PATCH", data, signal);
    const received = Number(asRow(result.data).received);
    if (!Number.isFinite(received) || received <= offset) throw new Error("Upload did not advance. Retry to resume.");
    offset = received; progress(Math.round(offset / file.size * 100));
  }
  const result = await backend(`/predictions/uploads/${uploadId}/finalize`, "POST", {}, signal);
  sessionStorage.removeItem(key);
  return result;
}
