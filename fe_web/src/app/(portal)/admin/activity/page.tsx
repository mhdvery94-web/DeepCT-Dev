import { ModulePage } from "@/components/module-page";
import { requireAdmin } from "@/lib/api";

export default async function ActivityPage() {
  await requireAdmin();
  return <ModulePage eyebrow="Administration" title="Activity logs" description="Audit user, prediction, model and administration events across the platform." />;
}
