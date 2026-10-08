"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { backend } from "@/lib/client-api";
import type { DeepCtUser } from "@/lib/types";

export function ProfileSettings({ user }: { user: DeepCtUser }) {
  const router = useRouter();
  const [message, setMessage] = useState(""); const [error, setError] = useState(""); const [busy, setBusy] = useState(false);
  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError("");
    try { const data = new FormData(event.currentTarget); const file = data.get("avatar"); if (!(file instanceof File) || file.size > 2 * 1024 * 1024) throw new Error("Select an image up to 2 MB."); const result = await backend("/me/avatar", "POST", data); setMessage(result.message ?? "Photo updated."); router.refresh(); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to save photo."); }
    finally { setBusy(false); }
  }
  return <section className="module-panel"><h2>{user.name}</h2><p>{user.email} · {user.role === "admin" ? "Administrator" : "Researcher"}</p>
    {/* eslint-disable-next-line @next/next/no-img-element */}
    {user.avatar_url && <img className="profile-photo" src={`/api/backend/users/${user.id}/avatar`} alt="Your profile photo" />}
    {error && <p className="form-message form-message--error" role="alert">{error}</p>}{message && <p className="form-message form-message--success" role="status">{message}</p>}
    <form className="module-form" onSubmit={save}><label><span>Profile photo (JPEG, PNG, WebP; up to 2 MB)</span><input type="file" name="avatar" accept="image/jpeg,image/png,image/webp" required /></label><button className="button button--primary" disabled={busy}>Save profile photo</button><button className="button button--secondary" type="button" disabled={busy} onClick={async () => { if (!window.confirm("Remove your profile photo?")) return; setBusy(true); setError(""); try { await backend("/me/avatar", "DELETE"); setMessage("Photo removed."); router.refresh(); } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to remove photo."); } finally { setBusy(false); } }}>Remove photo</button></form>
    <Link className="button button--secondary" href="/change-password">Change password</Link>
  </section>;
}
