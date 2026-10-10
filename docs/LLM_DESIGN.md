# Rancangan asisten LLM

**Pelaksanaan diminta 10 Oktober 2026, belum dirilis.** Aplikasi tetap khusus prediksi CT.
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

Keputusan pengguna terbaru: MVP memakai **DeepSeek R1 1.5B yang sudah tersedia
di Ollama Raspberry Pi**, bukan mengunduh model lain. Model 7B/14B tidak dimuat
bersamaan dengan API/database pada Pi 8 GB. Rekomendasi provider berikut adalah
alternatif historis, bukan konfigurasi MVP yang aktif.

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

## Pelaksanaan tujuh tahap (disetujui pengguna)

Kontrak MVP terbaru memakai tabel `ai_conversations`, `ai_messages`,
`ai_requests`, API `/ai/conversations` dan antrean `llm`. Istilah
assistant_sessions di atas adalah usulan lama, bukan nama tabel yang dibuat.

### Global Constraints

- Laravel adalah otoritas auth/ownership; Flutter dan Next.js membaca data yang sama.
- DeepSeek `deepseek-r1:1.5b` melalui Ollama loopback Pi; fitur default nonaktif sampai benchmark/UAT diterima.
- LLM hanya membaca metadata prediksi milik pengguna; tidak membaca raw TIFF/ZIP, menjalankan SQL/shell atau mengubah model CT.
- Warna BRIN `#B91C1C`, putih/slate/navy. UI mengikuti referensi chat mobile/web, bukan label Gemini/Kimi.
- Bobot model CT di TUF. Upload byte langsung dari klien ke HTTPS TUF, bukan melalui Pi/Vercel.
- Versi bobot immutable, adapter harus disetujui, manifest dan SHA256 wajib. Publikasi tidak sama dengan aktivasi.
- Satu generasi LLM aktif; antrean terpisah. Existing CT endpoint tetap tersedia selama migrasi.
- Tidak ada penghapusan model/data produksi atau penghentian proses GPU lain. Promosi develop, staging, main hanya setelah pemeriksaan lulus.

### Review Focus

1. Pencabutan akun setelah antrean masuk: worker tidak boleh mengirim konteksnya.
2. Restart saat upload potongan: offset/hash dan versi tidak boleh rusak atau tertimpa.
3. Model tidak kompatibel: jangan menjalankan kode dari checkpoint yang diunggah.
4. Respons R1 hanya reasoning: jangan tampilkan `<think>` sebagai jawaban selesai.
5. Frontend staging: jangan diam-diam mengubah database produksi.

### Task 1: Fondasi antrean dan upgrade aman

Files: `be/config/queue.php`, `be/.env.example`, migration purge historis,
`be/tests/Feature/QueueSafetyTest.php`, workflow web, docs operasi.
Interfaces: default CT queue `database/default`, timeout job 7200 detik;
connection `llm` driver database dengan queue `llm`, retry_after > timeout LLM.
- [ ] Tulis dan jalankan test RED: job CT reserved 100 detik tidak diambil ulang;
      migration purge lama tidak menghapus model atau relasi prediksi yang masih hidup.
- [ ] Tetapkan retry_after CT minimal 7260 (termasuk env override terlalu kecil),
      llm retry_after 360 dengan timeout job 300; lindungi historical purge sebagai no-op.
- [ ] Jalankan suite MySQL terisolasi. Expected: seluruh tes lulus.
- [ ] Pisahkan URL develop/staging dari fallback produksi; dokumentasikan prasyarat staging.
- [ ] Commit hanya berkas tugas ini.

### Task 2: DeepSeek dan API asisten

Files: config `be/config/ai.php`; migration tiga tabel AI; models AiConversation,
AiMessage, AiRequest; `API/AiConversationController.php`; `GenerateAiReply.php`;
services AiContext/OllamaClient; API routes; tests `AiAssistantTest.php`.
Interfaces: authenticated GET/POST `/ai/conversations`, GET detail/history,
POST `/{id}/messages` menerima `{content, idempotency_key, analysis_record_id?}`,
GET `/ai/requests/{id}`, POST `/ai/requests/{id}/cancel`. Envelope existing success/data.
POST messages menjawab 202 dengan request queued; detail berisi messages
dan request status queued/processing/completed/failed/cancelled. History paginated.
- [ ] RED: anon ditolak, ownership lintas akun 404, disabled 503, input kosong 422,
      satu request aktif/user, idempotency replay, worker akun dicabut, cancel,
      Ollama timeout dan response reasoning-only gagal tanpa mengekspos reasoning.
- [ ] GREEN: context 2048, output budget 768 token termasuk reasoning,
      paling banyak 8 history messages / 6000 karakter, satu worker `--queue=llm`;
      timeout 300, tries 1; limit queue 10 dan per user 20 request/hari atomik.
- [ ] Model tag/prompt version, Ollama token/duration dan error aman dicatat.
      Metrik/sumber metadata ditampilkan terpisah dari jawaban generatif.
- [ ] Suite backend lulus, benchmark Pi dilaporkan nyata, bukan asumsi dari ukuran bobot.
- [ ] Commit hanya task ini; jangan mengaktifkan fitur produksi sebelum gate.

### Task 3: UI chat dua frontend

Files: Next `research-assistant.tsx`, route `/workspace/assistant`, portal nav/CSS;
Flutter `ai_service.dart`, `research_assistant_screen.dart`, admin/user shell;
unit/widget tests dan web browser checks.
Interfaces: gunakan API Task 2, kedua role memiliki percakapan sendiri.
- [ ] RED: history/render pesan, send disabled saat aktif, cancel/retry, error nyata,
      navigasi admin/user, SafeArea/keyboard mobile tanpa overflow.
- [ ] GREEN: sidebar history 270 px desktop, drawer mobile, composer sticky;
      bubble user kanan/asisten kiri, salin, chat baru, sumber prediksi opsional.
      Jangan menampilkan voice/camera/branch palsu. Gerak reduced-motion aman.
- [ ] Flutter analyze/tests dan Next lint/typecheck/tests/build lulus.
- [ ] Commit task UI.

### Task 4: Registry model TUF berversi

Files: `deepct-model-server/app/{main,registry}.py`, loaders/tensorflow.py,
adapters/ginet_tcd.py, config, lockfile, Python tests.
Interfaces: root `deepct-models/<model_id>/<semver>/{manifest.json,model.h5|model.keras}`;
GET `/models` kompatibel dengan katalog Laravel; immutable endpoint
POST `/predict/{model_id}/{version}`. Adapter `ginet-tcd-v1` meniru pre/postprocessing
legacy 1024x1024, range 0..65535, t=0.5 dan custom TimeMean/TimeLast/SkipFusion.
- [ ] RED: manifest invalid/path traversal/duplikat versi ditolak, katalog tidak
      memuat TensorFlow/GPU, checksums berubah ditolak; compatibility adapter test.
- [ ] GREEN: lazy loader satu model dan lock inference, tidak membaca semua bobot saat catalog.
      TensorFlow safe_mode dan allowlist custom layers; tidak menerima pickle/Python upload.
- [ ] Copy bobot existing tanpa menghapus sumber; SHA256 diverifikasi. Jangan swap
      production worker sebelum parity inference nyata dan kapasitas GPU tersedia.
- [ ] Python suite lulus; commit code terpisah dari bobot/secret.

### Task 5: Upload model langsung ke TUF

Files: Python upload sessions/API, Laravel ModelUploadController/service/migration,
Next model-upload form, Flutter model-upload dialog/service, tests.
Interfaces: Laravel admin POST `/admin/model-uploads` mengirim metadata ke configured
TUF internal server dan mengembalikan HTTPS public URL plus token singkat scoped upload;
GET session/renew/finalize/cancel via Laravel. Klien PUT potongan 4 MiB langsung TUF
dengan offset. Server tidak menerima path/adaptor source dari klien.
- [ ] RED: anon/non-admin ditolak, token salah/expired/cross-session, offset salah,
      checksum salah, restart/resume, ukuran/disk guard, duplicate version, permission revoked.
- [ ] GREEN: session durable `.incoming`, token 15 menit, renewal oleh Laravel;
      uploaded/validating/ready_for_test/ready_for_activate/active/cancelled/failed state.
      file slice native ranged I/O, status poll/reconcile dan progress/cancel/resume.
- [ ] Validasi manifest/hash/format; load dan GPU test hanya dengan kapasitas tersedia.
      Atomic publish dan admin activation terpisah; registry DB idempotent mempertahankan display metadata.
- [ ] Suite Python/backend/frontend lulus; commit task upload.

### Task 6: Integrasi dan penerimaan

Files: tests/smoke scripts dan docs API/architecture/checkpoint.
- [ ] Jalankan API nyata terisolasi dan browser kedua role pada 1366/768/390 px.
- [ ] Uji chat/history mobile-web, upload putus/resume/cancel, TUF unavailable,
      model duplicate/hash mismatch, revoked role, LLM coexist dengan CT/API.
- [ ] Uji parity adapter pada TIFF reference terhadap worker existing. Expected:
      output shape/dtype/preprocessing sama dan hasil numerik/paritas tercatat.
- [ ] Bedakan fixture/mock, build, benchmark dan UAT GPU nyata dalam laporan.

### Task 7: Review dan rilis bertahap

Files: workflow/deploy instructions dan docs/checkpoint.
- [ ] Fresh-context review seluruh perubahan; perbaiki issue Critical/Important dengan test RED/GREEN.
- [ ] Deploy staging dengan database/storage sendiri, backup dan fitur flags rollback.
- [ ] Promosi develop ke staging; produksi main hanya setelah gate UAT terpenuhi.
- [ ] Catat commit, CI, HTTP/runtime checks, rollback dan semua blocker yang belum selesai.
