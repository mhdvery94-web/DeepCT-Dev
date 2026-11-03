import Link from "next/link";
import "../../../assistant.css";

export default function AssistantPage() {
  return (
    <section className="assistant-development" aria-labelledby="assistant-development-title">
      <div className="assistant-development__mark" aria-hidden="true">AI</div>
      <p className="assistant-development__eyebrow">DeepCT Research Assistant</p>
      <h1 id="assistant-development-title">Dalam Pengembangan</h1>
      <p>
        Asisten prediksi sedang menjalani validasi kualitas, keamanan, dan
        keandalan provider. Fitur ini akan tersedia kembali setelah seluruh
        pengujian staging dinyatakan lulus.
      </p>
      <div className="assistant-development__notice" role="status">
        Prediksi, preview frame, dan unduhan hasil tetap dapat digunakan seperti biasa.
      </div>
      <Link className="button button--primary" href="/workspace/predictions">
        Kembali ke prediksi
      </Link>
    </section>
  );
}
