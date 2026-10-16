import { analysisStatusLabels, analysisFacts, comparisonFacts, measurementFacts, parseAiSources, providerMetric, type AiRequest, type EvidenceFact } from "@/lib/assistant";

function Facts({ facts }: { facts: EvidenceFact[] }) {
  return <dl>{facts.map(({ label, value }) => <div className="assistant-evidence__fact" key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl>;
}

export function AssistantEvidence({ request }: { request: AiRequest }) {
  const sources = parseAiSources(request.sources);
  return (
    <details className="assistant-evidence">
      <summary>Sumber dan metrik tepercaya</summary>
      <p>Metadata ini dicatat saat jawaban dibuat, bukan status terkini. Gunakan sumber ini untuk memeriksa jawaban; asisten tidak membaca piksel TIFF.</p>
      {!sources.some(source => source.type === "analysis_record") && <p>Tidak ada konteks prediksi.</p>}
      {sources.map(source => source.type === "document" ? (
        <section key={`document-${source.id}`} aria-label={`Dokumen SOP ${source.id}`}>
          <h3>Dokumen SOP · {source.title}</h3>
          <p>{source.id} · {source.version}</p><p>{source.text}</p>
        </section>
      ) : (
        <section key={`analysis-${source.id}`} aria-label={`Snapshot prediksi ${source.id}`}>
          <h3>Prediksi #{source.id} · {analysisStatusLabels[source.status]}</h3>
          <Facts facts={analysisFacts(source)} />
          <h4>Metrik prediksi</h4><Facts facts={measurementFacts(source.evaluation)} />
          <details><summary>Metode pengukuran</summary>{source.evaluation.method.length ? <Facts facts={source.evaluation.method} /> : <p>Tidak tersedia</p>}</details>
          <h4>Baseline linear</h4>
          <p>{source.evaluation.baseline.status === "completed" ? "Baseline selesai" : source.evaluation.baseline.status === "baseline_failed" ? "Pengukuran baseline gagal" : "Baseline tidak tersedia"}</p>
          <Facts facts={measurementFacts(source.evaluation.baseline)} />
          {source.evaluation.baseline.method.length > 0 && <Facts facts={source.evaluation.baseline.method} />}
          <h4>Selisih terhadap baseline</h4>
          <p>{source.evaluation.comparison.status === "completed" ? "Presisi metrik tersimpan (recorded_precision). Nilai negatif berarti lebih buruk dari baseline." : "Perbandingan tidak tersedia."}</p>
          <Facts facts={comparisonFacts(source.evaluation)} />
          <small>Metrik dan provenans model tidak menyatakan persetujuan ilmiah.</small>
        </section>
      ))}
      <h3>Metrik generasi</h3>
      <Facts facts={Object.entries({ prompt_eval_count: "Token input", eval_count: "Token output", total_duration: "Durasi total", load_duration: "Durasi pemuatan", prompt_eval_duration: "Durasi input", eval_duration: "Durasi output" }).map(([key, label]) => ({ label, value: providerMetric(key, request.metrics?.[key]) }))} />
      <small>Durasi server dikonversi dari nanodetik ke detik.</small>
    </details>
  );
}
