import { providerMetric, type AiRequest } from "@/lib/assistant";

export function AssistantEvidence({ request }: { request: AiRequest }) {
  return (
    <details className="assistant-evidence">
      <summary>Sumber dan metrik tepercaya</summary>
      <p>
        Metadata ini dicatat saat jawaban dibuat, bukan status terkini. Gunakan sumber ini untuk memeriksa jawaban; asisten tidak membaca piksel TIFF.
      </p>
      {request.sources.length === 0 && <p>Tidak ada konteks prediksi.</p>}
      {request.sources.map((source) => (
        <section key={source.id}>
          <h3>
            Prediksi #{source.id} · {source.status}
          </h3>
          <dl>
            <dt>Model CT</dt>
            <dd>
              {source.model
                ? source.model.provenance === "historical_model_snapshot_unavailable"
                  ? "Versi historis / provenans model tidak tersedia"
                  : "name" in source.model ? `${source.model.name} · ${source.model.version}` : "Tidak tersedia"
                : "Tidak tersedia"}
            </dd>
            <dt>Jumlah berkas input / hasil</dt>
            <dd>
              {source.input_files_count ?? "Tidak tersedia"} /{" "}
              {source.output_files_count ?? "Tidak tersedia"}
            </dd>
            <dt>Waktu analisis</dt>
            <dd>
              {source.processing_time_seconds == null
                ? "Tidak tersedia"
                : `${source.processing_time_seconds} detik`}
            </dd>
            <dt>Berkas kedaluwarsa / dihapus</dt>
            <dd>
              {source.expired ? "Ya" : "Tidak"} /{" "}
              {source.files_deleted ? "Ya" : "Tidak"}
            </dd>
            {[
              "mae",
              "psnr",
              "ssim",
              "rmse",
              "pixels",
              "reference_min",
              "reference_max",
            ].map((key) => (
              <div className="assistant-evidence__fact" key={key}>
                <dt>{key}</dt>
                <dd>{source.metrics[key] ?? "Tidak tersedia"}</dd>
              </div>
            ))}
          </dl>
          <details>
            <summary>Provenans validasi dan frame</summary>
            <pre>
              {JSON.stringify(
                {
                  validation: source.validation_provenance,
                  frames: source.frame_provenance,
                },
                null,
                2,
              )}
            </pre>
          </details>
        </section>
      ))}
      <h3>Metrik generasi</h3>
      <dl>
        {[
          "prompt_eval_count",
          "eval_count",
          "total_duration",
          "load_duration",
          "prompt_eval_duration",
          "eval_duration",
        ].map((key) => (
          <div className="assistant-evidence__fact" key={key}>
            <dt>
              {
                (
                  {
                    prompt_eval_count: "Token input",
                    eval_count: "Token output",
                    total_duration: "Durasi total",
                    load_duration: "Durasi pemuatan",
                    prompt_eval_duration: "Durasi input",
                    eval_duration: "Durasi output",
                  } as Record<string, string>
                )[key]
              }
            </dt>
            <dd>{providerMetric(key, request.metrics?.[key])}</dd>
          </div>
        ))}
      </dl>
      <small>Durasi server dikonversi dari nanodetik ke detik.</small>
    </details>
  );
}
