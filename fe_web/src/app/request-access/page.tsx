import Link from "next/link";
import { JoinForm } from "@/components/join-form";
import { Brand } from "@/components/brand";

export const metadata = { title: "Request research access" };

export default function RequestAccessPage() {
  return <main className="public-form-page"><Brand /><section className="auth-card">
    <Link className="auth-card__back" href="/login">← Back to login</Link>
    <h2>Request research access</h2><p>Tell us about your research. An administrator will review your request.</p>
    <JoinForm />
  </section></main>;
}
