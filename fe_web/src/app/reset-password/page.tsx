import Link from "next/link";
import { Brand } from "@/components/brand";
import { ResetRequestForm } from "@/components/reset-request-form";

export const metadata = { title: "Reset password" };

export default function ResetPasswordPage() {
  return <main className="public-form-page"><Brand /><section className="auth-card">
    <Link className="auth-card__back" href="/login">← Back to login</Link>
    <h2>Reset password</h2><p>Enter your registered email and phone number. Matching requests are reviewed by the administrator before the password is reset to its issued default.</p>
    <ResetRequestForm />
  </section></main>;
}
