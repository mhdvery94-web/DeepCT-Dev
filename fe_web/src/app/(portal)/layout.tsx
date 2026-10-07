import type { ReactNode } from "react";
import { redirect } from "next/navigation";
import { PortalShell } from "@/components/portal-shell";
import { requireUser } from "@/lib/api";

export default async function PortalLayout({ children }: { children: ReactNode }) {
  const user = await requireUser();
  if (user.must_change_password) redirect("/change-password");
  return <PortalShell user={user}>{children}</PortalShell>;
}
