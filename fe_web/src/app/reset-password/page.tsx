import Link from "next/link";
import { Brand } from "@/components/brand";
import { ResetRequestForm } from "@/components/reset-request-form";

export const metadata = { title: "Reset password" };

export default function ResetPasswordPage() {
  return <main className="public-form-page"><Brand /><section className="auth-card">
    <Link className="auth-card__back" href="/login">← Back to login</Link>
    <h2>Reset password</h2><p>Request a reset to the issued default password. Your administrator will verify the request before resetting your account.</p>
    <ResetRequestForm />
  </section></main>;
}
