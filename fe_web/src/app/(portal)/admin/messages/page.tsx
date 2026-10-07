import { ModulePage } from "@/components/module-page";
import { requireAdmin } from "@/lib/api";

export default async function AdminMessagesPage() {
  await requireAdmin();
  return <ModulePage eyebrow="Administration" title="Messages" description="Read and reply to authenticated researcher and public support conversations." />;
}
