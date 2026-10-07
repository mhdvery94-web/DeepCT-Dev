import { ModulePage } from "@/components/module-page";
import { requireUser } from "@/lib/api";

export default async function TrainingPage() {
  await requireUser();
  return <ModulePage eyebrow="Research workspace" title="Model training" description="Create training jobs and inspect metrics, samples and registered outputs." />;
}
