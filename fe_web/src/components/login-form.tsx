"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import type { DeepCtUser } from "@/lib/types";

export function LoginForm({ nextPath = "/dashboard" }: { nextPath?: string }) {
  const router = useRouter();
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setSubmitting(true);

    const formData = new FormData(event.currentTarget);
    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          email: formData.get("email"),
          password: formData.get("password"),
        }),
      });
      const payload = (await response.json().catch(() => null)) as
        | { message?: string; data?: { user?: DeepCtUser } }
        | null;

      if (!response.ok) {
        throw new Error(payload?.message ?? "Login gagal. Periksa kembali akun Anda.");
      }

      const destination = payload?.data?.user?.must_change_password
        ? "/change-password"
        : nextPath;
      router.replace(destination);
      router.refresh();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Terjadi kesalahan tak terduga.");
      setSubmitting(false);
    }
  }

  return (
    <form className="auth-form" onSubmit={submit}>
      <label>
        <span>Email</span>
        <input type="email" name="email" autoComplete="email" required autoFocus />
      </label>
      <label>
        <span>Password</span>
        <input type="password" name="password" autoComplete="current-password" required />
      </label>
      {error && (
        <p className="form-message form-message--error" role="alert">
          {error}
        </p>
      )}
      <button className="button button--primary button--wide" disabled={submitting}>
        {submitting ? "Signing in…" : "Login"}
      </button>
    </form>
  );
}
