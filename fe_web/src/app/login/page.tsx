import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { Brand } from "@/components/brand";
import { LoginForm } from "@/components/login-form";
import { getCurrentUser } from "@/lib/api";

export const metadata: Metadata = { title: "Login" };

function safeNextPath(value?: string): string {
  if (!value?.startsWith("/") || value.startsWith("//") || /[\\\x00-\x1f]/.test(value)) return "/dashboard";
  return value;
}

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const user = await getCurrentUser();
  if (user) redirect(user.must_change_password ? "/change-password" : "/dashboard");
  const params = await searchParams;

  return (
    <main className="auth-page">
      <section className="auth-copy">
        <Brand />
        <div className="auth-copy__body">
          <span className="eyebrow eyebrow--light">Secure research workspace</span>
          <h1>From raw CT data to research insight.</h1>
          <p>
            Continue to predictions, research news, and administration
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
          <div className="auth-actions">
            <Link className="button button--secondary button--wide" href="/request-access">Request access</Link>
            <Link href="/reset-password">Reset password to default</Link>
          </div>
          <p className="auth-help">
            Password resets are reviewed by an administrator. You will be asked to change the issued password after signing in.
          </p>
        </div>
      </section>
    </main>
  );
}
