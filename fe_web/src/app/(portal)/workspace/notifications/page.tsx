import { ModulePage } from "@/components/module-page";
import { requireUser } from "@/lib/api";

export default async function Page() {
  await requireUser();
  return <ModulePage eyebrow="Workspace" title="Notifications" description="Read updates about your research jobs and account." />;
}
