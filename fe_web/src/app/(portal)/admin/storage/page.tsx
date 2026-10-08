import { requireAdmin } from "@/lib/api";
import { StorageManagement } from "@/components/storage-management";

export default async function StoragePage() {
  await requireAdmin();
  return <main className="portal-content"><header className="portal-heading"><div><span className="eyebrow">Administration</span><h1>Disk management</h1><p>Monitor disk capacity and reclaim application files from finished research jobs.</p></div></header><StorageManagement /></main>;
}
