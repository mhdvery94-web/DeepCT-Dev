import { ModulePage } from "@/components/module-page";
import { requireAdmin } from "@/lib/api";

export default async function Page() {
  await requireAdmin();
  return <ModulePage eyebrow="Workspace" title="Training oversight" description="Inspect progress, cancel runs and register finished model weights." />;
}
