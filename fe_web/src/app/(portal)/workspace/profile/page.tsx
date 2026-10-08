import { requireUser } from "@/lib/api";
import { ProfileSettings } from "@/components/profile-settings";

export default async function ProfilePage() {
  const user = await requireUser();
  return <main className="portal-content"><header className="portal-heading"><div><span className="eyebrow">Research workspace</span><h1>Account settings</h1><p>Manage your profile photo and account security.</p></div></header><ProfileSettings user={user} /></main>;
}
