# Rancangan asisten LLM

**Usulan, belum diimplementasikan.** Aplikasi tetap khusus prediksi CT.
Asisten menjelaskan hasil/model/metrik; tidak menghasilkan TIFF atau melatih
model. Dokumentasi provider diperiksa 9 Oktober 2026.

## Kesiapan frontend

Fondasi yang dapat dipakai: login/role, gateway Pi, detail/history prediksi,
provenance/validation, perbandingan model, dialog responsif dan error/loading.
Belum ada panel Assistant, penyimpanan chat, penggunaan token/kuota, provider
LLM maupun penanganan respons percakapan. Registry model CT tetap terpisah
dari konfigurasi provider LLM.

MVP menambahkan tombol Explain result di detail prediksi dan panel percakapan
yang terikat prediction ID, pilihan pertanyaan awal, sumber data, status
menunggu/error/retry/cancel, serta informasi kuota. Mobile memakai sheet/dialog
yang bisa digulir. Respons bertahap SSE dapat ditambahkan setelah endpoint
dan batas durasi hosting diuji; MVP boleh menggunakan job async/polling.

## Pilihan model

| Pilihan | Pemakaian |
|---|---|
| GPT-5 mini melalui OpenAI API | Rekomendasi MVP: function calling, output terstruktur dan streaming tersedia |
| Gemini 3.8 Flash melalui Gemini API | Alternatif cloud yang tercantum dalam model resmi; evaluasi kualitas/biaya pada contoh riset sendiri |
| Qwen3 8B melalui Ollama | Inference lokal pada host tersendiri; tidak mengirim konteks ke cloud, tetapi perlu kapasitas hardware dan operasi |

Model/provider dipilih setelah benchmark Bahasa Indonesia, kesetiaan metrik,
latency, output schema dan biaya. Tidak ada jaminan model terbaik dari namanya.
Pi bertugas mengorkestrasi; model lokal sebaiknya berada di host lain agar
tidak berebut RAM/CPU dengan API/MySQL/queue. Bobot 8B dan context cache
memerlukan lebih banyak memori daripada sekadar ukuran unduhan.

Sumber resmi:
[GPT-5 mini](https://developers.openai.com/api/docs/models/gpt-5-mini),
[Gemini models](https://ai.google.dev/gemini-api/docs/models),
[Qwen3/Ollama](https://ollama.com/library/qwen3).

## Logika bisnis

1. User membuka prediksi miliknya dan meminta penjelasan. Laravel memeriksa
   token, akun, ownership/role, entitlement asisten dan kuota.
2. Server membaca status/model/version, jumlah frame, validation,
   frame_provenance dan relasi rerun. ID resource berasal dari konteks yang
   telah diotorisasi; LLM tidak menentukan akun yang boleh dibaca.
3. Untuk completed, jelaskan metrik yang benar-benar tersedia. Pending/failed
   hanya mendapat penjelasan status/error. Expired boleh dijelaskan dari
   metadata/evidence yang masih ada, tanpa mengaku membaca TIFF yang terhapus.
4. Server membangun konteks ringkas. Raw ZIP/TIFF, credential dan data akun lain
   tidak dikirim. Provider key disimpan di backend, terpisah dari token worker CT.
5. LLM menjawab schema terstruktur: ringkasan, pengamatan dengan sumber ID/metrik,
   keterbatasan dan saran pemeriksaan. Nilai numerik/perbandingan dihitung server.
   Validasi schema dan angka sebelum menampilkan; data yang tidak ada disebutkan
   sebagai tidak tersedia, bukan ditebak.
6. Simpan jawaban, referensi sumber, provider/model, prompt version, penggunaan
   token dan latency. UI menampilkan sumber serta dapat meminta penjelasan ulang.

Percakapan memakai tabel assistant_sessions/messages/usage terpisah dari pesan
dukungan. Endpoint usulan: POST /assistant/sessions, POST /assistant/sessions/{id}/messages,
GET /assistant/messages/{id}. Nama ini adalah rancangan, bukan route aktif.
Job LLM memakai antrean terpisah; kegagalan/limit LLM tidak menghentikan prediksi.

Admin mengatur provider aktif, kuota per user/hari, batas token/konteks serta
budget harian; reservation dilakukan atomik sebelum panggilan dan direkonsiliasi
setelahnya. Retry terbatas dan idempotency menghindari tagihan duplikat.
Cache harus terikat owner, prediction ID, versi hasil/prompt dan model LLM.
LLM hanya mendapat tool baca: ringkasan prediksi, perbandingan rerun dan
dokumen yang disetujui. Ia tidak diberi tool training/delete/reset/deploy.

## Tahap penerapan

Mulai dari penjelasan satu hasil dan metrik dengan sumber. Tambahkan perbandingan
antar-run yang valid, lalu pencarian/RAG atas dokumen penelitian yang disetujui.
Uji kebocoran akun, angka palsu/missing metrics, expired output, batas kuota,
timeout/cancel, retry/idempotency dan kualitas Bahasa Indonesia sebelum produksi.
Asisten membantu interpretasi; keputusan ilmiah tetap memerlukan pemeriksaan
peneliti dan penerimaan model CT.
