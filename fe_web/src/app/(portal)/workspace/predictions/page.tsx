import { ModulePage } from "@/components/module-page";
import { requireUser } from "@/lib/api";

export default async function PredictionsPage() {
  await requireUser();
  return <ModulePage eyebrow="Research workspace" title="Predictions" description="Upload CT datasets, choose a model and follow processing through completion." />;
}
