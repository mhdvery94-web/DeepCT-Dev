import type { Metadata } from "next";
import Link from "next/link";
import { Brand } from "@/components/brand";
import { LoginForm } from "@/components/login-form";

export const metadata: Metadata = { title: "Login" };

function safeNextPath(value?: string): string {
  if (!value?.startsWith("/") || value.startsWith("//")) return "/dashboard";
  return value;
}

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const params = await searchParams;

  return (
    <main className="auth-page">
      <section className="auth-copy">
        <Brand />
        <div className="auth-copy__body">
          <span className="eyebrow eyebrow--light">Secure research workspace</span>
          <h1>From raw CT data to research insight.</h1>
          <p>
            Continue to predictions, model training, research news, and administration
            tools using your institutional account.
          </p>
        </div>
        <p className="auth-copy__footer">Badan Riset dan Inovasi Nasional · 2026</p>
      </section>
      <section className="auth-panel">
        <div className="auth-card">
          <Link className="auth-card__back" href="/">
            ← Back to website
          </Link>
          <h2>Welcome back</h2>
          <p>Use the account issued by your administrator.</p>
          <LoginForm nextPath={safeNextPath(params.next)} />
          <p className="auth-help">
            Cannot access your account? Return to the website and use the support channel.
          </p>
        </div>
      </section>
    </main>
  );
}
