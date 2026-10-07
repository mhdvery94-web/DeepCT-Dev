import { ModulePage } from "@/components/module-page";
import { requireUser } from "@/lib/api";

export default async function MessagesPage() {
  await requireUser();
  return <ModulePage eyebrow="Research workspace" title="Messages" description="Keep your support conversation with the administrator in one thread." />;
}
