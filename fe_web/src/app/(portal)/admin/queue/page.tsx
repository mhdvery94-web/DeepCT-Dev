import { ModulePage } from "@/components/module-page";
import { requireAdmin } from "@/lib/api";

export default async function Page() {
  await requireAdmin();
  return <ModulePage eyebrow="Workspace" title="Queue monitor" description="See which jobs are processing and which researchers are waiting." />;
}
