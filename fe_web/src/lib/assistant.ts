export type AiMessage = { id: number; role: "user" | "assistant"; content: string; created_at: string };
export type AiConversation = { id: number; title: string; created_at: string; updated_at: string };
export type AiPagination = { current_page: number; last_page: number; per_page: number; total: number };
export type AiStatus = { enabled: boolean; model: string; experimental: true; prompt_version: string; limits: { message_characters: number; requests_per_day: number; queue: number; context_tokens: number; output_tokens: number; history_messages: number; history_characters: number; active_requests_per_user: number } };
export type AiSource = {
  type: "analysis_record"; id: number; status: string;
  input_files_count: number | null; output_files_count: number | null;
  processing_time_seconds: number | null; expired: boolean; files_deleted: boolean;
  model: { id: number | null; provenance: "historical_model_snapshot_unavailable" } | { id: number; name: string; slug: string | null; version: string; provenance?: string; model_id?: string; sha256?: string } | null;
  metrics: Record<string, number | null>; validation_provenance: Record<string, unknown>; frame_provenance: Record<string, unknown>[];
};
export type AiRequest = { id: number; conversation_id: number; user_message_id: number; analysis_record_id: number | null; status: "queued" | "processing" | "completed" | "failed" | "cancelled"; error_code: string | null; model: string; prompt_version: string; experimental: true; assistant_message: AiMessage | null; sources: AiSource[]; metrics: Record<string, number> | null };
export type AiDetail = AiConversation & { messages: AiMessage[]; pagination: AiPagination; request: AiRequest | null };
export type AiSubmission = { content: string; idempotency_key: string; analysis_record_id?: number };

export function regenerationSubmission(message: AiMessage, request: AiRequest, key: string): AiSubmission {
  return {
    content: message.content,
    idempotency_key: key,
    ...(request.analysis_record_id != null ? { analysis_record_id: request.analysis_record_id } : {}),
  };
}

export const activeRequest = (request: AiRequest | null | undefined) => request?.status === "queued" || request?.status === "processing";
export const requestLabels = { queued: "Dalam antrean", processing: "Sedang diproses", completed: "Selesai", failed: "Gagal", cancelled: "Dibatalkan" };
export function mergeMessages(previous: AiMessage[], incoming: AiMessage[]): AiMessage[] {
  const unique = new Map(previous.map(message => [message.id, message]));
  incoming.forEach(message => unique.set(message.id, message));
  return [...unique.values()].sort((a, b) => a.id - b.id);
}
export function providerMetric(key: string, value: number | null | undefined): string {
  if (value == null) return "Tidak tersedia";
  return key.endsWith("_duration") ? `${(value / 1_000_000_000).toFixed(1)} detik` : String(value);
}
