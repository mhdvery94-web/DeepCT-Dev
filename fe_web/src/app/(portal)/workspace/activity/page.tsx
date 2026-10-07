import { ModulePage } from "@/components/module-page";
import { requireUser } from "@/lib/api";

export default async function MyActivityPage() {
  await requireUser();
  return <ModulePage eyebrow="Research workspace" title="My activity" description="Review your own account, prediction, training and support events." />;
}
