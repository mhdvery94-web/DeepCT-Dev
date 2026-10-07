"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";

export function PasswordForm() {
  const router = useRouter();
  const [state, setState] = useState({ submitting: false, message: "", error: false });

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const values = new FormData(form);
    const password = String(values.get("password") ?? "");
    const confirmation = String(values.get("password_confirmation") ?? "");

    if (password !== confirmation) {
      setState({ submitting: false, error: true, message: "Konfirmasi password tidak sama." });
      return;
    }

    setState({ submitting: true, error: false, message: "" });
    try {
      const response = await fetch("/api/backend/me/password", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          current_password: values.get("current_password"),
          password,
          password_confirmation: confirmation,
        }),
      });
      const payload = (await response.json().catch(() => null)) as
        | { message?: string; errors?: Record<string, string[]> }
        | null;

      if (!response.ok) {
        const validation = payload?.errors
          ? Object.values(payload.errors).flat().find(Boolean)
          : undefined;
        throw new Error(validation ?? payload?.message ?? "Password tidak dapat diubah.");
      }

      setState({ submitting: false, error: false, message: "Password berhasil diubah." });
      router.replace("/dashboard");
      router.refresh();
    } catch (error) {
      setState({
        submitting: false,
        error: true,
        message: error instanceof Error ? error.message : "Terjadi kesalahan tak terduga.",
      });
    }
  }

  return (
    <form className="password-form" onSubmit={submit}>
      <label>
        <span>Current password</span>
        <input name="current_password" type="password" autoComplete="current-password" required />
      </label>
      <label>
        <span>New password</span>
        <input name="password" type="password" autoComplete="new-password" minLength={8} required />
      </label>
      <label>
        <span>Confirm new password</span>
        <input name="password_confirmation" type="password" autoComplete="new-password" minLength={8} required />
      </label>
      {state.message && (
        <p className={`form-message${state.error ? " form-message--error" : ""}`} role="status">
          {state.message}
        </p>
      )}
      <button className="button button--primary" disabled={state.submitting}>
        {state.submitting ? "Saving…" : "Change password"}
      </button>
    </form>
  );
}
