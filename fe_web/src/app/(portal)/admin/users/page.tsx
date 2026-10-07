import { ModulePage } from "@/components/module-page";
import { requireAdmin } from "@/lib/api";

export default async function UsersPage() {
  await requireAdmin();
  return <ModulePage eyebrow="Administration" title="User management" description="Manage researcher accounts, roles, status, avatars and password resets." />;
}
