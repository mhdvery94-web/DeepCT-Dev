import { ModulePage } from "@/components/module-page";
import { requireAdmin } from "@/lib/api";

export default async function Page() {
  await requireAdmin();
  return <ModulePage eyebrow="Workspace" title="Training datasets" description="Manage reusable training archives and remove unused datasets." />;
}
