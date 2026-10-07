import { ModulePage } from "@/components/module-page";
import { requireAdmin } from "@/lib/api";

export default async function AccessRequestsPage() {
  await requireAdmin();
  return <ModulePage eyebrow="Administration" title="Access requests" description="Review, approve or reject incoming researcher access requests." />;
}
