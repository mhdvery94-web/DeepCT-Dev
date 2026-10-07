import { ModulePage } from "@/components/module-page";
import { requireUser } from "@/lib/api";

export default async function ModelsPage() {
  await requireUser();
  return <ModulePage eyebrow="Research workspace" title="Available models" description="Explore models the administrator has enabled for your prediction workflows." />;
}
