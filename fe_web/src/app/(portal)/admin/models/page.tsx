import { ModulePage } from "@/components/module-page";
import { requireAdmin } from "@/lib/api";

export default async function ModelManagementPage() {
  await requireAdmin();
  return <ModulePage eyebrow="Administration" title="Model management" description="Register model endpoints, run health checks and control researcher availability." />;
}
