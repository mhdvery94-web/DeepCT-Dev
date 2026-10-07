import type { Metadata } from "next";
import { PasswordForm } from "@/components/password-form";
import { requireUser } from "@/lib/api";

export const metadata: Metadata = { title: "Change password" };

export default async function ChangePasswordPage() {
  await requireUser();

  return (
    <main className="portal-content">
      <header className="portal-heading">
        <div>
          <span className="eyebrow">Account security</span>
          <h1>Change your password</h1>
          <p>
            Set a private password before opening the rest of your research workspace.
          </p>
        </div>
      </header>
      <PasswordForm />
    </main>
  );
}
