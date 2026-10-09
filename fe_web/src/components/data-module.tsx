"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";
import { NewsMediaManager } from "@/components/news-media-manager";
import { Modal } from "@/components/modal";
import { asRow, asRows, backend, bytes, display, type ApiResult, type Row } from "@/lib/client-api";

type Field = { name: string; label: string; type?: string; required?: boolean; max?: number; options?: string[] };
type Config = { path: string; columns: string[]; fields?: Field[]; updateMethod?: string; readOnly?: boolean; filters?: string[] };
const name: Field = { name: "name", label: "Name", required: true, max: 255 };
const description: Field = { name: "description", label: "Description", type: "textarea", max: 2000 };
const registryFields: Field[] = [name, { name: "version", label: "Version", required: true, max: 50 }, { name: "endpoint_url", label: "Worker endpoint", type: "url", required: true, max: 500 }, description, { name: "auth_token", label: "Worker token (leave blank to keep existing)", type: "password", max: 500 }, { name: "verify_tls", label: "Verify TLS certificate", type: "checkbox" }];
const configs: Record<string, Config> = {
  "User management": { path: "/admin/users", columns: ["name", "email", "role", "is_active", "last_login_at"], fields: [name, { name: "email", label: "Email", type: "email", required: true, max: 255 }, { name: "phone", label: "Phone", max: 30 }, { name: "role", label: "Role", options: ["user", "admin"], required: true }], filters: ["active", "inactive"] },
  "Model management": { path: "/admin/models", columns: ["name", "version", "status", "is_active"], fields: registryFields, filters: ["online", "offline", "trouble"] },
  "Available models": { path: "/me/models", columns: ["name", "version", "status", "description"], readOnly: true },
  "Access requests": { path: "/admin/access-requests", columns: ["first_name", "last_name", "email", "phone", "institution", "status"], filters: ["pending", "approved", "rejected"] },
  "Research news": { path: "/admin/news", columns: ["title", "summary", "is_published", "published_at"], updateMethod: "POST", fields: [{ name: "title", label: "Title", required: true, max: 200 }, { name: "summary", label: "Summary", type: "textarea", required: true, max: 500 }, { name: "body", label: "Full article", type: "textarea", max: 20000 }, { name: "sort_order", label: "Slide order", type: "number" }, { name: "is_published", label: "Published", type: "checkbox" }], filters: ["published", "draft"] },
  "Messages": { path: "/messages", columns: [] },
  "Support inbox": { path: "/admin/conversations", columns: ["name", "guest_email", "preview", "unread", "is_archived"], filters: ["active", "archived"] },
  "Activity logs": { path: "/admin/activities", columns: ["created_at", "user", "activity_type", "description"], readOnly: true },
  "My activity": { path: "/me/activities", columns: ["created_at", "activity_type", "description"], readOnly: true },
  "Notifications": { path: "/notifications", columns: ["created_at", "title", "body", "read"] },
  "Queue monitor": { path: "/admin/queue", columns: ["user", "job_id", "model", "status", "queue_position"], readOnly: true },
};

function label(value: string) { return value.replaceAll("_", " ").replace(/^./, (letter) => letter.toUpperCase()); }

export function DataModule({ title }: { title: string }) {
  const config = configs[title];
  const [result, setResult] = useState<ApiResult>();
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [issuedPassword, setIssuedPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const [editing, setEditing] = useState<Row | null | undefined>();
  const [detail, setDetail] = useState<Row>();
  const [media, setMedia] = useState<Row>();

  const refresh = useCallback(async (signal?: AbortSignal) => {
    if (!config) return;
    const params = new URLSearchParams({ page: String(page), per_page: "20" });
    if (search) params.set("search", search);
    if (status) params.set(title === "Support inbox" ? "archived" : "status", title === "Support inbox" ? status === "archived" ? "1" : "0" : status);
    try {
      const response = await backend(`${config.path}?${params}`, "GET", undefined, signal);
      setResult(response); setError(""); setLoading(false);
    } catch (reason) { if (!signal?.aborted) { setError(reason instanceof Error ? reason.message : "Unable to load data."); setLoading(false); } }
  }, [config, page, search, status, title]);

  useEffect(() => { const controller = new AbortController(); void Promise.resolve().then(() => refresh(controller.signal)); return () => controller.abort(); }, [refresh]);
  useEffect(() => {
    const timer = window.setInterval(() => { if (!document.hidden) void refresh(); }, 15000);
    return () => window.clearInterval(timer);
  }, [refresh]);


  if (!config) return <p role="alert">Unknown workspace module.</p>;
  let rows = asRows(result?.data);
  if (title === "Queue monitor") { const board = asRow(result?.data); rows = [...asRows(board.running), ...asRows(board.waiting)]; }

  async function action(path: string, method: string, body?: FormData | Record<string, unknown>, confirmation?: string) {
    if (confirmation && !window.confirm(confirmation)) return;
    setBusy(true); setError(""); setNotice(""); setIssuedPassword("");
    try {
      const response = await backend(path, method, body);
      setNotice(response.message ?? "Saved.");
      const password = response.default_password ?? asRow(response.data).default_password;
      if (password) setIssuedPassword(String(password));
      await refresh(); return response;
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Request failed."); }
    finally { setBusy(false); }
  }
  async function view(row: Row) {
    const canFetch = !config.readOnly && title !== "Access requests" && title !== "Notifications";
    try { setDetail(canFetch ? asRow((await backend(`${config.path}/${row.id}`)).data) : row); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to open details."); }
  }
  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget; const data = new FormData(form);
    let payload: FormData | Record<string, unknown>;
    if (title === "Research news") {
      config.fields?.filter((field) => field.type === "checkbox").forEach((field) => data.set(field.name, data.has(field.name) ? "1" : "0"));
      payload = data;
    } else {
      payload = Object.fromEntries(data);
      for (const field of config.fields ?? []) {
        if (field.type === "checkbox") payload[field.name] = data.has(field.name);
        if (field.type === "number") payload[field.name] = Number(data.get(field.name) || 0);
      }
      if (editing && payload.auth_token === "") delete payload.auth_token;
    }
    const response = await action(`${config.path}${editing ? `/${editing.id}` : ""}`, editing ? config.updateMethod ?? "PUT" : "POST", payload);
    if (response) setEditing(undefined);
  }

  const closeDetail = () => setDetail(undefined);
  return <div className="data-module" aria-busy={loading || busy}>
    <div className="module-toolbar">
      <form onSubmit={(event) => { event.preventDefault(); setPage(1); setSearch(query); }}><label className="sr-only" htmlFor="module-search">Search</label><input id="module-search" placeholder="Search records" value={query} onChange={(event) => setQuery(event.target.value)} /><button className="button button--secondary" disabled={busy}>Search</button></form>
      {config.filters && <select aria-label="Filter by status" value={status} onChange={(event) => { setPage(1); setStatus(event.target.value); }}><option value="">All statuses</option>{config.filters.map((value) => <option key={value}>{value}</option>)}</select>}
      <button className="button button--secondary" disabled={busy} onClick={() => void refresh()}>Refresh</button>
      {config.fields && <button className="button button--primary" disabled={busy} onClick={() => setEditing(null)}>Create {title === "Research news" ? "article" : "record"}</button>}
      {title === "Available models" && <button className="button button--primary" disabled={busy} onClick={() => void action("/me/models/refresh", "POST", {})}>Check availability</button>}
      {title.includes("activity") || title === "Activity logs" ? <button className="button button--secondary" onClick={() => {
        const csv = [config.columns, ...rows.map((row) => config.columns.map((key) => { const value = display(row[key]); return /^[=+@\-\t\r]/.test(value) ? `'${value}` : value; }))].map((line) => line.map((value) => `"${value.replaceAll('"', '""')}"`).join(",")).join("\r\n");
        const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" })); const anchor = document.createElement("a"); anchor.href = url; anchor.download = "activity-page.csv"; anchor.click(); URL.revokeObjectURL(url);
      }}>Export this page</button> : null}
      {title === "Notifications" && <button className="button button--secondary" disabled={busy} onClick={() => void action("/notifications/read-all", "POST", {})}>Mark all read</button>}
    </div>
    {error && <p className="form-message form-message--error" role="alert">{error}</p>}
    {notice && <p className="form-message form-message--success" role="status">{notice}</p>}
    {issuedPassword && <p className="issued-password" role="status">Issued password: <code>{issuedPassword}</code> <button onClick={() => setIssuedPassword("")}>Dismiss</button></p>}
    {typeof result?.meta?.queue_message === "string" && <p className="module-note">{result.meta.queue_message}</p>}

    {title === "Messages" ? <section className="module-panel"><h2>Your support conversation</h2><MessageList messages={asRows(asRow(result?.data).messages)} />
      <form className="module-form" onSubmit={async (event) => { event.preventDefault(); const form = event.currentTarget; if (await action("/messages", "POST", Object.fromEntries(new FormData(form)))) form.reset(); }}><label><span>Message</span><textarea name="body" required maxLength={5000} rows={4} /></label><button className="button button--primary" disabled={busy}>Send message</button></form>
      <button className="button button--secondary" disabled={busy} onClick={() => void action("/messages/read", "POST", {})}>Mark replies read</button>
    </section> : <>
      <div className="module-table-wrap"><table className="module-table"><thead><tr>{config.columns.map((key) => <th key={key}>{label(key)}</th>)}<th>Actions</th></tr></thead><tbody>
        {rows.map((row, index) => <tr key={row.id || index}>{config.columns.map((key) => <td key={key}>{key === "size_bytes" ? bytes(row[key]) : display(row[key])}</td>)}<td><div className="row-actions">
          <button disabled={busy} onClick={() => void view(row)}>Details</button>
          {config.fields && <button disabled={busy} onClick={() => setEditing(row)}>{title === "Research news" ? "Edit article" : "Edit"}</button>}
          {title === "Research news" && <button disabled={busy} onClick={async () => { try { setMedia(asRow((await backend(`/admin/news/${row.id}`)).data)); } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to load media."); } }}>Manage media</button>}
          {["User management", "Model management", "Research news"].includes(title) && <button disabled={busy} onClick={() => void action(`${config.path}/${row.id}/toggle`, "PATCH", {}, "Change availability of this record?")}>{row.is_active === false || row.is_published === false ? "Enable" : "Disable"}</button>}
          {title === "User management" && <><button disabled={busy} onClick={() => void action(`${config.path}/${row.id}/reset-password`, "POST", {}, "Reset this account to its default password and revoke its sessions?")}>Reset password</button><button disabled={busy} onClick={() => { setDetail(row); }}>Profile</button></>}
          {title === "Model management" && <><button disabled={busy} onClick={() => void action(`${config.path}/${row.id}/health-check`, "POST", {})}>Health check</button><button disabled={busy} onClick={() => void action(`${config.path}/${row.id}/test`, "POST", {}, "Run an inference test using the GPU worker?")}>Test</button></>}
          {title === "Access requests" && row.status === "pending" && <><button disabled={busy} onClick={() => void action(`${config.path}/${row.id}/approve`, "POST", {}, "Approve this request and issue an account?")}>Approve</button><button disabled={busy} onClick={() => { const note = window.prompt("Reason for rejection (optional)"); if (note !== null) void action(`${config.path}/${row.id}/reject`, "POST", { note }); }}>Reject</button></>}
          {title === "Support inbox" && <button disabled={busy} onClick={() => void action(`${config.path}/${row.id}`, "PATCH", { is_archived: !row.is_archived })}>{row.is_archived ? "Restore" : "Archive"}</button>}
          {title === "Notifications" && row.read === false && <button disabled={busy} onClick={() => void action(`/notifications/${row.id}/read`, "POST", {})}>Mark read</button>}
          {!config.readOnly && title !== "Messages" && <button className="danger-action" disabled={busy} onClick={() => void action(`${config.path}/${row.id}`, "DELETE", undefined, "Permanently delete this record and its application files?")}>Delete</button>}
        </div></td></tr>)}
        {!rows.length && <tr><td colSpan={config.columns.length + 1}>{loading ? "Loading records…" : error ? "Unable to load records. Use Refresh to try again." : "No records found."}</td></tr>}
      </tbody></table></div>
      {result?.pagination && <div className="module-pagination"><span>{result.pagination.total} records · page {result.pagination.current_page} / {result.pagination.last_page}</span><button className="button button--secondary" disabled={busy || page <= 1} onClick={() => setPage(page - 1)}>Previous</button><button className="button button--secondary" disabled={busy || page >= result.pagination.last_page} onClick={() => setPage(page + 1)}>Next</button></div>}
    </>}

    {media && <NewsMediaManager post={media} onClose={() => setMedia(undefined)} onChanged={() => refresh()} />}
    {editing !== undefined && <Modal labelledBy="edit-title" onClose={() => setEditing(undefined)} busy={busy}><h2 id="edit-title">{title === "Research news" ? editing ? "Edit article" : "Create article" : editing ? "Edit record" : "Create record"}</h2>
      {title === "Research news" && <p className="module-note">Save your article first, then use Manage media to upload its image and video separately.</p>}
      <form className="module-form" onSubmit={save}>
        {config.fields?.map((field) => <label key={field.name}><span>{field.label}</span>{field.type === "textarea" ? <textarea name={field.name} rows={field.name === "body" ? 10 : 3} defaultValue={editing ? String(editing[field.name] ?? "") : ""} required={field.required} maxLength={field.max} /> : field.options ? <select name={field.name} defaultValue={String(editing?.[field.name] ?? field.options[0])}>{field.options.map((option) => <option key={option}>{option}</option>)}</select> : field.type === "checkbox" ? <input name={field.name} type="checkbox" defaultChecked={field.name === "verify_tls" ? editing?.verify_tls !== false : Boolean(editing?.[field.name])} /> : <input name={field.name} type={field.type ?? "text"} defaultValue={field.type === "file" || field.type === "password" ? undefined : String(editing?.[field.name] ?? (field.type === "number" ? 0 : ""))} maxLength={field.max} required={field.required} autoComplete={field.type === "password" ? "new-password" : undefined} />}</label>)}
        {error && <p className="form-message form-message--error" role="alert">{error}</p>}
        <div className="module-actions"><button className="button button--primary" disabled={busy}>{busy ? "Saving…" : "Save"}</button><button className="button button--secondary" type="button" disabled={busy} onClick={() => setEditing(undefined)}>Cancel</button></div>
      </form></Modal>}
    {detail && <Modal labelledBy="detail-title" onClose={closeDetail} busy={busy}><div className="module-actions"><h2 id="detail-title">Record details</h2><button className="button button--secondary" onClick={closeDetail}>Close</button></div>
      <dl className="record-details">{Object.entries(detail).filter(([key]) => !["messages", "rerun", "register"].includes(key)).map(([key, value]) => <div key={key}><dt>{label(key)}</dt><dd>{display(value)}</dd></div>)}</dl>
      {title === "Research news" && <div className="record-media">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        {detail.has_image === true && <img src={`/api/backend/news/${detail.id}/image`} alt={String(detail.title)} />}
        {detail.has_video === true && <video src={`/api/backend/news/${detail.id}/video`} controls playsInline preload="metadata" />}
      </div>}
      {title === "Support inbox" && <><MessageList messages={asRows(detail.messages)} /><form className="module-form" onSubmit={async (event) => { event.preventDefault(); const form = event.currentTarget; if (await action(`${config.path}/${detail.id}/reply`, "POST", Object.fromEntries(new FormData(form)))) { form.reset(); await view(detail); } }}><label><span>Reply</span><textarea name="body" required maxLength={5000} /></label><button className="button button--primary" disabled={busy}>Send reply</button></form><button className="button button--secondary" disabled={busy} onClick={() => void action(`${config.path}/${detail.id}/read`, "POST", {})}>Mark read</button></>}
      {title === "User management" && <form className="module-form" onSubmit={async (event) => { event.preventDefault(); const data = new FormData(event.currentTarget); if (await action(`/admin/users/${detail.id}/avatar`, "POST", data)) await view(detail); }}><label><span>Profile photo (JPEG, PNG, WebP; up to 2 MB)</span><input name="avatar" type="file" required accept="image/jpeg,image/png,image/webp" /></label><button className="button button--primary" disabled={busy}>Upload photo</button><button className="button button--secondary" type="button" disabled={busy} onClick={() => void action(`/admin/users/${detail.id}/avatar`, "DELETE", undefined, "Remove this profile photo?")}>Remove photo</button></form>}

      {error && <p className="form-message form-message--error" role="alert">{error}</p>}
    </Modal>}
  </div>;
}

function MessageList({ messages }: { messages: Row[] }) {
  return <div className="message-list">{messages.length ? messages.map((message) => <article className={message.from_admin ? "from-admin" : ""} key={message.id}><strong>{display(message.author)}</strong><time>{display(message.created_at)}</time><p>{display(message.body)}</p></article>) : <p>No messages yet.</p>}</div>;
}
