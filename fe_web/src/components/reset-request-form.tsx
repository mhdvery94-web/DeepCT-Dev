"use client";

import { useState, type FormEvent } from "react";

export function ResetRequestForm() {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError("");
    const form = event.currentTarget;
    const data = new FormData(form);
    try {
      const response = await fetch("/api/backend/messages/public", {
        method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ name: data.get("name"), email: data.get("email"), body: `Password reset request: please verify my identity and reset my account to the default password. ${data.get("reason") ?? ""}` }),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.message ?? "Unable to send the request.");
      setMessage("Request received. The administrator will verify your identity and contact you through your institutional email.");
      form.reset();
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to send the request."); }
    finally { setBusy(false); }
  }
  return message ? <p className="form-message form-message--success" role="status">{message}</p> : <form className="auth-form" onSubmit={submit}>
    <label><span>Full name</span><input name="name" autoComplete="name" required maxLength={100} /></label>
    <label><span>Institutional email</span><input name="email" type="email" autoComplete="email" required maxLength={150} /></label>
    <label><span>Department / additional information (optional)</span><textarea name="reason" rows={3} maxLength={1500} /></label>
    {error && <p className="form-message form-message--error" role="alert">{error}</p>}
    <button className="button button--primary button--wide" disabled={busy}>{busy ? "Sending…" : "Request password reset"}</button>
  </form>;
}
