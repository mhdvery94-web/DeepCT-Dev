import { ModulePage } from "@/components/module-page";
import { requireUser } from "@/lib/api";
import { redirect } from "next/navigation";

export default async function PredictionsPage() {
  const user = await requireUser();
  if (user.role === "admin") redirect("/admin/queue");
  return <ModulePage eyebrow="Research workspace" title="Predictions" description="Upload CT datasets, choose a model and follow processing through completion." />;
}
