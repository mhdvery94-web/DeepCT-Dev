"use client";

import { FormEvent, useState } from "react";

type FormState = { status: "idle" | "submitting" | "success" | "error"; message: string };

export function JoinForm() {
  const [state, setState] = useState<FormState>({ status: "idle", message: "" });

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState({ status: "submitting", message: "" });

    const form = event.currentTarget;
    const data = new FormData(form);
    const payload = Object.fromEntries(data.entries());

    try {
      const response = await fetch("/api/backend/access-requests", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(payload),
      });
      const result = (await response.json().catch(() => null)) as
        | { message?: string; errors?: Record<string, string[]> }
        | null;

      if (!response.ok) {
        const validation = result?.errors
          ? Object.values(result.errors).flat().find(Boolean)
          : undefined;
        throw new Error(validation ?? result?.message ?? "Permintaan belum dapat dikirim.");
      }

      form.reset();
      setState({
        status: "success",
        message: result?.message ?? "Permintaan diterima dan akan ditinjau administrator.",
      });
    } catch (error) {
      setState({
        status: "error",
        message: error instanceof Error ? error.message : "Terjadi kesalahan tak terduga.",
      });
    }
  }

  if (state.status === "success") {
    return (
      <div className="form-success" role="status">
        <span aria-hidden="true">✓</span>
        <h3>Request received</h3>
        <p>{state.message}</p>
        <button
          className="button button--secondary"
          type="button"
          onClick={() => setState({ status: "idle", message: "" })}
        >
          Submit another
        </button>
      </div>
    );
  }

  return (
    <form className="join-form" onSubmit={submit}>
      <div className="form-grid">
        <label>
          <span>First name</span>
          <input name="first_name" autoComplete="given-name" required maxLength={100} />
        </label>
        <label>
          <span>Last name</span>
          <input name="last_name" autoComplete="family-name" required maxLength={100} />
        </label>
      </div>
      <label>
        <span>Institutional email</span>
        <input name="email" type="email" autoComplete="email" required maxLength={255} />
      </label>
      <label>
        <span>Department / institution</span>
        <input name="institution" autoComplete="organization" required maxLength={255} />
      </label>
      <label>
        <span>Research purpose <small>(optional)</small></span>
        <textarea name="reason" rows={4} maxLength={2000} />
      </label>

      {state.status === "error" && (
        <p className="form-message form-message--error" role="alert">
          {state.message}
        </p>
      )}

      <button className="button button--primary button--wide" disabled={state.status === "submitting"}>
        {state.status === "submitting" ? "Sending…" : "Submit request"}
      </button>
    </form>
  );
}
