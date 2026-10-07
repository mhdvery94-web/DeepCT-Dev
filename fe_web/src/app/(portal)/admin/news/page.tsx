import { ModulePage } from "@/components/module-page";
import { requireAdmin } from "@/lib/api";

export default async function NewsManagementPage() {
  await requireAdmin();
  return <ModulePage eyebrow="Administration" title="Research news" description="Draft, publish and order image or video stories shown on the public website." />;
}
