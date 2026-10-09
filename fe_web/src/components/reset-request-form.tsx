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
      const response = await fetch("/api/backend/password-reset-requests", {
        method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ email: data.get("email"), phone: data.get("phone") }),
      });
      const result = await response.json().catch(() => null);
      if (!response.ok || result?.success === false) {
        const validation = result?.errors ? Object.values(result.errors).flat().find((value) => typeof value === "string") : undefined;
        throw new Error(String(validation ?? result?.message ?? "Unable to send the request."));
      }
      setMessage(result?.message ?? "Account matched. Your reset request is awaiting administrator verification.");
      form.reset();
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to send the request."); }
    finally { setBusy(false); }
  }
  return message ? <p className="form-message form-message--success" role="status">{message}</p> : <form className="auth-form" onSubmit={submit}>
    <label><span>Registered email</span><input name="email" type="email" autoComplete="email" placeholder="ayu.pratama@institution.ac.id" required maxLength={255} /></label>
    <label><span>Registered phone number</span><input name="phone" type="tel" autoComplete="tel" placeholder="+6281234567890" required maxLength={30} /></label>
    <p className="auth-help">Both fields must match the same active account. If your account has no registered phone number, contact your administrator.</p>
    {error && <p className="form-message form-message--error" role="alert">{error}</p>}
    <button className="button button--primary button--wide" disabled={busy}>{busy ? "Checking account…" : "Find account and request reset"}</button>
  </form>;
}
