import { ResearchAssistant } from "@/components/research-assistant";
import "../../../assistant.css";

export default async function AssistantPage({ searchParams }: { searchParams: Promise<{ analysis_record_id?: string }> }) {
  const params = await searchParams;
  const id = Number(params.analysis_record_id);
  return <ResearchAssistant analysisRecordId={Number.isSafeInteger(id) && id > 0 ? id : undefined} />;
}
