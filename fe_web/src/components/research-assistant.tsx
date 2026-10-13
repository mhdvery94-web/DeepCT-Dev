"use client";

import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type FormEvent,
} from "react";
import { backend, BackendError } from "@/lib/client-api";
import {
  activeRequest,
  mergeMessages,
  regenerationSubmission,
  requestLabels,
  type AiConversation,
  type AiDetail,
  type AiMessage,
  type AiPagination,
  type AiRequest,
  type AiStatus,
  type AiSubmission,
} from "@/lib/assistant";
import { AssistantEvidence } from "@/components/assistant-evidence";

const messageOf = (error: unknown) =>
  error instanceof Error
    ? error.message
    : "Permintaan tidak dapat diselesaikan.";

export function ResearchAssistant({
  analysisRecordId,
}: {
  analysisRecordId?: number;
}) {
  const [status, setStatus] = useState<AiStatus>();
  const [conversations, setConversations] = useState<AiConversation[]>([]);
  const [historyPage, setHistoryPage] = useState<AiPagination>();
  const [conversation, setConversation] = useState<AiConversation>();
  const [messages, setMessages] = useState<AiMessage[]>([]);
  const [messagePage, setMessagePage] = useState<AiPagination>();
  const [request, setRequest] = useState<AiRequest | null>(null);
  const [knownActive, setKnownActive] = useState<AiRequest | null>(null);
  const [draft, setDraft] = useState("");
  const [contextId, setContextId] = useState(analysisRecordId);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [pollError, setPollError] = useState("");
  const [copied, setCopied] = useState<number>();
  const [drawer, setDrawer] = useState(false);
  const [pollRevision, setPollRevision] = useState(0);
  const [pending, setPending] = useState<AiSubmission>();
  const session = useRef<AbortController | null>(null);
  const detail = useRef<AbortController | null>(null);
  const operations = useRef(false);
  const historySequence = useRef(0);
  const pollEpoch = useRef(0);
  const end = useRef<HTMLDivElement>(null);
  const messageViewport = useRef<HTMLDivElement>(null);
  const historyAnchor = useRef<{ height: number; top: number } | null>(null);
  const drawerToggle = useRef<HTMLButtonElement>(null);
  const drawerPanel = useRef<HTMLElement>(null);
  const requestId = request?.id;
  const requestStatus = request?.status;

  const loadHistory = useCallback(
    async (page: number, signal?: AbortSignal) => {
      const sequence = ++historySequence.current;
      const result = (
        await backend(
          `/ai/conversations?page=${page}`,
          "GET",
          undefined,
          signal,
        )
      ).data as { conversations: AiConversation[]; pagination: AiPagination };
      if (!signal?.aborted && sequence === historySequence.current) {
        setConversations(result.conversations);
        setHistoryPage(result.pagination);
      }
    },
    [],
  );
  const initialize = useCallback(
    async (signal: AbortSignal) => {
      setLoading(true);
      setError("");
      try {
        const config = await backend("/ai/status", "GET", undefined, signal);
        if (!signal.aborted) setStatus(config.data as AiStatus);
        await loadHistory(1, signal);
      } catch (reason) {
        if (!signal.aborted) setError(messageOf(reason));
      } finally {
        if (!signal.aborted) setLoading(false);
      }
    },
    [loadHistory],
  );
  useEffect(() => {
    const controller = new AbortController();
    session.current = controller;
    void Promise.resolve().then(() => initialize(controller.signal));
    return () => {
      controller.abort();
      detail.current?.abort();
    };
  }, [initialize]);

  const acceptRequest = useCallback((incoming: AiRequest) => {
    setRequest(incoming);
    setKnownActive((previous) =>
      activeRequest(incoming)
        ? incoming
        : previous?.id === incoming.id
          ? null
          : previous,
    );
    if (incoming.assistant_message)
      setMessages((previous) =>
        mergeMessages(previous, [incoming.assistant_message!]),
      );
  }, []);
  useEffect(() => {
    if (!requestId || !["queued", "processing"].includes(requestStatus ?? ""))
      return;
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout>;
    const epoch = pollEpoch.current;
    const poll = async () => {
      try {
        const incoming = (
          await backend(
            `/ai/requests/${requestId}`,
            "GET",
            undefined,
            controller.signal,
          )
        ).data as AiRequest;
        if (controller.signal.aborted || epoch !== pollEpoch.current) return;
        setPollError("");
        acceptRequest(incoming);
        if (activeRequest(incoming)) timer = setTimeout(poll, 3000);
        else
          void loadHistory(1, session.current?.signal).catch((reason) => {
            if (!session.current?.signal.aborted) setError(messageOf(reason));
          });
      } catch (reason) {
        if (!controller.signal.aborted && epoch === pollEpoch.current)
          setPollError(messageOf(reason));
      }
    };
    timer = setTimeout(poll, 1000);
    return () => {
      controller.abort();
      clearTimeout(timer);
    };
  }, [requestId, requestStatus, pollRevision, acceptRequest, loadHistory]);
  useLayoutEffect(() => {
    const viewport = messageViewport.current;
    const anchor = historyAnchor.current;
    historyAnchor.current = null;
    if (viewport && anchor) {
      viewport.scrollTop = anchor.top + viewport.scrollHeight - anchor.height;
    } else {
      end.current?.scrollIntoView({ block: "end", behavior: "instant" });
    }
  }, [messages.length, request?.status]);
  useEffect(() => {
    if (!drawer) return;
    const panel = drawerPanel.current;
    panel?.querySelector<HTMLButtonElement>("button")?.focus();
    const keydown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setDrawer(false);
        drawerToggle.current?.focus();
      }
      if (event.key === "Tab") {
        const focusable = panel?.querySelectorAll<HTMLButtonElement>(
          "button:not(:disabled)",
        );
        if (!focusable?.length) return;
        const first = focusable[0],
          last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    };
    const resize = () => {
      if (window.innerWidth > 900) setDrawer(false);
    };
    document.addEventListener("keydown", keydown);
    window.addEventListener("resize", resize);
    return () => {
      document.removeEventListener("keydown", keydown);
      window.removeEventListener("resize", resize);
    };
  }, [drawer]);

  async function openConversation(item: AiConversation) {
    if (operations.current || pending) return;
    ++pollEpoch.current;
    historyAnchor.current = null;
    detail.current?.abort();
    const controller = new AbortController();
    detail.current = controller;
    setDrawer(false);
    setConversation(item);
    setMessages([]);
    setMessagePage(undefined);
    setRequest(null);
    setPollError("");
    setError("");
    setLoading(true);
    setDraft("");
    setContextId(analysisRecordId);
    try {
      const result = (
        await backend(
          `/ai/conversations/${item.id}`,
          "GET",
          undefined,
          controller.signal,
        )
      ).data as AiDetail;
      if (controller.signal.aborted) return;
      setConversation(result);
      setMessages(result.messages);
      setMessagePage(result.pagination);
      if (result.request) acceptRequest(result.request);
    } catch (reason) {
      if (!controller.signal.aborted) setError(messageOf(reason));
    } finally {
      if (!controller.signal.aborted) setLoading(false);
    }
  }
  async function olderMessages() {
    if (!conversation || !messagePage || operations.current) return;
    setBusy(true);
    operations.current = true;
    const signal = detail.current?.signal;
    try {
      const result = (
        await backend(
          `/ai/conversations/${conversation.id}?page=${messagePage.current_page + 1}`,
          "GET",
          undefined,
          signal,
        )
      ).data as AiDetail;
      if (signal?.aborted) return;
      const viewport = messageViewport.current;
      if (viewport)
        historyAnchor.current = {
          height: viewport.scrollHeight,
          top: viewport.scrollTop,
        };
      setMessages((previous) => mergeMessages(previous, result.messages));
      setMessagePage(result.pagination);
    } catch (reason) {
      if (!signal?.aborted) setError(messageOf(reason));
    } finally {
      operations.current = false;
      if (!signal?.aborted) setBusy(false);
    }
  }
  function newChat() {
    if (operations.current || pending) return;
    ++pollEpoch.current;
    historyAnchor.current = null;
    detail.current?.abort();
    setConversation(undefined);
    setMessages([]);
    setMessagePage(undefined);
    setRequest(null);
    setDraft("");
    setError("");
    setPollError("");
    setLoading(false);
    setDrawer(false);
    setContextId(analysisRecordId);
  }
  async function send(submission?: AiSubmission) {
    if (
      !status?.enabled ||
      activeRequest(request) ||
      knownActive ||
      operations.current ||
      loading
    )
      return;
    const payload = submission ?? {
      content: draft.trim(),
      idempotency_key: crypto.randomUUID(),
      ...(contextId ? { analysis_record_id: contextId } : {}),
    };
    if (!payload.content) return;
    operations.current = true;
    setBusy(true);
    setError("");
    const signal = session.current?.signal;
    try {
      let current = conversation;
      if (!current) {
        current = (await backend("/ai/conversations", "POST", {}, signal))
          .data as AiConversation;
        if (signal?.aborted) return;
        setConversation(current);
      }
      setPending(payload);
      const result = (
        await backend(
          `/ai/conversations/${current.id}/messages`,
          "POST",
          payload,
          signal,
        )
      ).data as { request: AiRequest; user_message: AiMessage };
      if (signal?.aborted) return;
      setMessages((previous) => mergeMessages(previous, [result.user_message]));
      acceptRequest(result.request);
      setPending(undefined);
      setDraft("");
      setPollError("");
      void loadHistory(1, signal).catch((reason) => {
        if (!signal?.aborted) setError(messageOf(reason));
      });
    } catch (reason) {
      if (!signal?.aborted) {
        setError(messageOf(reason));
        if (
          reason instanceof BackendError &&
          (reason.status < 500 || reason.errorCode === "assistant_disabled")
        ) {
          setPending(undefined);
          if (reason.errorCode === "assistant_disabled")
            setStatus(
              (previous) => previous && { ...previous, enabled: false },
            );
        }
      }
    } finally {
      operations.current = false;
      if (!signal?.aborted) setBusy(false);
    }
  }
  async function cancel() {
    if (!request || operations.current) return;
    ++pollEpoch.current;
    operations.current = true;
    setBusy(true);
    setError("");
    const signal = session.current?.signal;
    try {
      const result = await backend(
        `/ai/requests/${request.id}/cancel`,
        "POST",
        {},
        signal,
      );
      if (!signal?.aborted) {
        acceptRequest(result.data as AiRequest);
        setPollError("");
      }
    } catch (reason) {
      if (!signal?.aborted) setError(messageOf(reason));
    } finally {
      operations.current = false;
      if (!signal?.aborted) {
        setBusy(false);
        setPollRevision((value) => value + 1);
      }
    }
  }
  async function copy(message: AiMessage) {
    try {
      await navigator.clipboard.writeText(message.content);
      setCopied(message.id);
    } catch {
      setError(
        "Tidak dapat menyalin. Pilih teks pesan untuk menyalin secara manual.",
      );
    }
  }
  const lastUser = messages.find(
    (message) => message.id === request?.user_message_id,
  );
  const blocked =
    !status?.enabled ||
    activeRequest(request) ||
    !!knownActive ||
    busy ||
    loading ||
    !!pending;
  const onSubmit = (event: FormEvent) => {
    event.preventDefault();
    void send();
  };

  return (
    <section className="research-assistant" aria-label="Asisten riset BRIN">
      {drawer && (
        <button
          className="assistant-history-backdrop"
          aria-label="Tutup riwayat"
          onClick={() => {
            setDrawer(false);
            drawerToggle.current?.focus();
          }}
        />
      )}
      <aside
        ref={drawerPanel}
        className={`assistant-history${drawer ? " is-open" : ""}`}
        aria-label="Riwayat percakapan"
        {...(drawer ? { role: "dialog", "aria-modal": true } : {})}
      >
        <div className="assistant-history__heading">
          <strong>Percakapan saya</strong>
          <button
            className="assistant-history-close"
            aria-label="Tutup riwayat"
            onClick={() => {
              setDrawer(false);
              drawerToggle.current?.focus();
            }}
          >
            ×
          </button>
        </div>
        <button
          className="button button--primary"
          disabled={busy || !!pending}
          onClick={newChat}
        >
          + Chat baru
        </button>
        <p>Riwayat pribadi akun Anda</p>
        <nav aria-label="Daftar percakapan">
          {conversations.map((item) => (
            <button
              key={item.id}
              aria-label={item.title}
              disabled={busy || !!pending}
              aria-current={item.id === conversation?.id ? "page" : undefined}
              onClick={() => void openConversation(item)}
            >
              <span>{item.title}</span>
              <small>
                {new Date(item.updated_at).toLocaleDateString("id-ID")}
              </small>
            </button>
          ))}
        </nav>
        {historyPage && (
          <div className="assistant-pagination">
            <button
              aria-label="Percakapan sebelumnya"
              disabled={historyPage.current_page <= 1 || busy}
              onClick={() =>
                void loadHistory(
                  historyPage.current_page - 1,
                  session.current?.signal,
                ).catch((reason) => setError(messageOf(reason)))
              }
            >
              ←
            </button>
            <span>
              {historyPage.current_page} / {historyPage.last_page}
            </span>
            <button
              aria-label="Percakapan berikutnya"
              disabled={
                historyPage.current_page >= historyPage.last_page || busy
              }
              onClick={() =>
                void loadHistory(
                  historyPage.current_page + 1,
                  session.current?.signal,
                ).catch((reason) => setError(messageOf(reason)))
              }
            >
              →
            </button>
          </div>
        )}
      </aside>
      <div className="assistant-chat">
        <header className="assistant-chat__header">
          <button
            ref={drawerToggle}
            className="assistant-history-toggle"
            aria-label="Riwayat percakapan"
            aria-expanded={drawer}
            onClick={() => setDrawer(true)}
          >
            ☰
          </button>
          <div>
            <h1>{conversation?.title ?? "Asisten riset"}</h1>
            <p>
              BRIN · {status?.model ?? "DeepSeek"} <span>Eksperimental</span>
            </p>
          </div>
          <button
            className="assistant-new-mobile"
            disabled={busy || !!pending}
            aria-label="Chat baru"
            onClick={newChat}
          >
            +
          </button>
        </header>
        <div className="assistant-disclaimer" role="status">
          {status?.enabled
            ? "DeepSeek eksperimental. Verifikasi jawaban sebelum digunakan dalam riset."
            : "DeepSeek eksperimental belum tersedia sampai evaluasi kualitas lulus. Riwayat tetap dapat dibaca."}
        </div>
        <div
          ref={messageViewport}
          className="assistant-messages"
          aria-label="Pesan percakapan"
          aria-busy={loading}
        >
          {loading && <p role="status">Memuat percakapan…</p>}
          {messagePage && messagePage.current_page < messagePage.last_page && (
            <button
              className="assistant-older"
              disabled={busy}
              onClick={() => void olderMessages()}
            >
              Pesan lebih lama
            </button>
          )}
          {!loading && messages.length === 0 && (
            <div className="assistant-welcome">
              <div className="assistant-mark">BRIN</div>
              <h2>Ruang diskusi riset Anda</h2>
              <p>
                Tanyakan tentang status atau hasil analisis CT. Konteks hanya
                memakai metadata prediksi milik Anda.
              </p>
              <p>
                Jawaban model adalah eksperimen; sumber tepercaya ditampilkan
                terpisah.
              </p>
            </div>
          )}
          {messages.map((message) => (
            <article
              key={message.id}
              className={`assistant-message assistant-message--${message.role}`}
            >
              <div className="assistant-message__label">
                {message.role === "user" ? "Anda" : "Asisten · eksperimental"}{" "}
                <time dateTime={message.created_at}>
                  {new Date(message.created_at).toLocaleTimeString("id-ID", {
                    hour: "2-digit",
                    minute: "2-digit",
                  })}
                </time>
              </div>
              <div className="assistant-message__bubble">{message.content}</div>
              <button
                aria-label={`Salin pesan ${message.id}`}
                onClick={() => void copy(message)}
              >
                {copied === message.id ? "Tersalin" : "Salin"}
              </button>
            </article>
          ))}
          {request && (
            <div className="assistant-request" role="status">
              <span>
                {requestLabels[request.status]}
                {request.status === "failed"
                  ? ` · ${request.error_code ?? "generation_failed"}`
                  : ""}
              </span>
              {activeRequest(request) && (
                <button disabled={busy} onClick={() => void cancel()}>
                  Batalkan
                </button>
              )}
              {["failed", "cancelled"].includes(request.status) && lastUser && (
                <button
                  disabled={blocked}
                  onClick={() =>
                    void send(
                      regenerationSubmission(
                        lastUser,
                        request,
                        crypto.randomUUID(),
                      ),
                    )
                  }
                >
                  Buat ulang jawaban
                </button>
              )}
            </div>
          )}
          {request?.status === "completed" && (
            <AssistantEvidence request={request} />
          )}
          <div ref={end} />
        </div>
        <div className="assistant-composer-area">
          {knownActive && knownActive.conversation_id !== conversation?.id && (
            <div className="assistant-context">
              <span>Permintaan lain masih aktif.</span>
              <button
                disabled={busy || !!pending}
                onClick={() =>
                  void openConversation(
                    conversations.find(
                      (item) => item.id === knownActive.conversation_id,
                    ) ?? {
                      id: knownActive.conversation_id,
                      title: `Percakapan #${knownActive.conversation_id}`,
                      created_at: "",
                      updated_at: "",
                    },
                  )
                }
              >
                Buka permintaan aktif
              </button>
            </div>
          )}
          {error && (
            <div className="assistant-error" role="alert">
              <span>{error}</span>
              {pending ? (
                <button
                  disabled={busy || !status?.enabled || activeRequest(request)}
                  onClick={() => void send(pending)}
                >
                  Coba kirim lagi
                </button>
              ) : (
                <button
                  disabled={busy}
                  onClick={() =>
                    conversation
                      ? void openConversation(conversation)
                      : session.current &&
                        void initialize(session.current.signal)
                  }
                >
                  Muat ulang
                </button>
              )}
            </div>
          )}
          {pollError && (
            <div className="assistant-error" role="alert">
              <span>{pollError}</span>
              <button
                disabled={busy}
                onClick={() => {
                  setPollError("");
                  setPollRevision((value) => value + 1);
                }}
              >
                Coba polling lagi
              </button>
            </div>
          )}
          {contextId && (
            <div className="assistant-context">
              Konteks prediksi #{contextId}
              <button
                disabled={busy || !!pending}
                onClick={() => setContextId(undefined)}
              >
                Lepas konteks
              </button>
            </div>
          )}
          <form className="assistant-composer" onSubmit={onSubmit}>
            <label className="sr-only" htmlFor="assistant-message">
              Pesan
            </label>
            <textarea
              id="assistant-message"
              value={draft}
              maxLength={status?.limits.message_characters ?? 2000}
              rows={2}
              disabled={busy || !!pending}
              placeholder="Tulis pertanyaan riset Anda…"
              onChange={(event) => setDraft(event.target.value)}
              onKeyDown={(event) => {
                if (
                  event.key === "Enter" &&
                  !event.shiftKey &&
                  !event.nativeEvent.isComposing
                ) {
                  event.preventDefault();
                  if (!blocked && draft.trim()) void send();
                }
              }}
            />
            <button
              className="button button--primary"
              type="submit"
              disabled={blocked || !draft.trim()}
            >
              Kirim
            </button>
          </form>
          <div className="assistant-composer__note">
            <span>Enter untuk mengirim · Shift+Enter untuk baris baru</span>
            <span>
              {draft.length}/{status?.limits.message_characters ?? 2000}
            </span>
          </div>
          {status?.limits.requests_per_day != null && (
            <small className="assistant-quota">
              Batas maksimum {status.limits.requests_per_day} permintaan per
              hari · Bukan sisa kuota
            </small>
          )}
        </div>
      </div>
    </section>
  );
}
