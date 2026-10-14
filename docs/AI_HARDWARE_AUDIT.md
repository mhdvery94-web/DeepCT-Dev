# Audit Hailo dan runtime AI — 14 Oktober 2026

Pernyataan bahwa DeepSeek R1 di Ollama menjadi lebih pintar dengan Hailo-8
tidak tepat untuk konfigurasi yang diperiksa. Akselerasi komputasi dan kualitas
jawaban merupakan dua hal berbeda. Raspberry Pi dapat menjalankan Ollama di
CPU, tetapi memasang Hailo-8 tidak otomatis membuat model GGUF Ollama memakai
NPU atau meningkatkan pengetahuan dan ketepatan model yang sama.

## Perangkat dan dukungan resmi

Pemeriksaan SSH Raspi pada 13 dan 14 Oktober melihat PCIe NVMe Silicon Motion,
Broadcom dan RP1; tidak mendeteksi perangkat Hailo, modul kernel Hailo atau
`hailortcli`. Ini menyatakan keadaan yang terdeteksi OS, bukan pemeriksaan fisik
apakah ada papan yang belum terpasang/terkonfigurasi.

[Tabel resmi Raspberry Pi](https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html)
menyatakan dukungan LLM **Not supported** pada AI HAT+ Hailo-8/8L, dan
**Supported** pada AI HAT+ 2 Hailo-10H dengan RAM onboard 8 GB. Hailo-8/8L
ditujukan untuk beban seperti deteksi objek dan pemrosesan kamera. Hailo-10H
memerlukan model/runtime yang didukung; dukungan board tersebut bukan bukti
bahwa instalasi Ollama ini sudah terintegrasi dengannya.

[Dokumentasi GPU Ollama](https://docs.ollama.com/gpu) tidak mencantumkan Hailo
sebagai backend akselerasi. Tidak ada uji pembanding dengan Hailo karena
perangkat/runtime tersebut tidak tersedia pada host yang diperiksa.

## Uji Ollama aktual

Ollama versi `0.11.4` memiliki tag DeepSeek R1 1.5b, 7b dan 14b. Uji hanya
memuat `deepseek-r1:1.5b`, memakai konteks 2048, dua thread CPU dan batas 64
token. Model lain tidak dimuat dan konfigurasi layanan tidak diubah.

| Pengukuran | Hasil |
|---|---|
| Processor dari `ollama ps` | 100% CPU |
| `size_vram` | 0 byte |
| Ukuran runtime menurut `ollama ps` | Sekitar 1.4 GB |
| Waktu load | 1.241 detik |
| Generasi | 64 token dalam 8.753 detik; 7.312 token/detik |
| Waktu keseluruhan probe | 12.258 detik, termasuk sampling health |
| Health API produksi/staging selama generasi | 12 sampel HTTP 200; 7.32–12.93 ms |

Ini probe perangkat, kecepatan dan coexistence, bukan load test atau penerimaan
kualitas jawaban. Generasi mencapai batas 64 token (`done_reason=length`).
Jawaban dan reasoning mentah tidak disimpan. Sampel kecil ini tidak menjamin
latency percakapan panjang. Lima kasus kualitas sebelumnya, dengan anggaran
768 token, gagal pada status pending, metrik hilang, caveat ilmiah, hasil
expired dan permintaan tidak aman. Fitur asisten produksi tetap nonaktif.

## Verifikasi aplikasi

| Komponen | Bukti dan batasnya |
|---|---|
| Laravel staging Raspi | Login kedua role HTTP 200; management admin 200, user 403, anonim 401; history 200; `/ai/status` melaporkan `enabled=false`. Token smoke dicabut. Database, APP_KEY dan storage terpisah. |
| Model CT di TUF | TensorFlow 2.17/Keras 3.15.1 berjalan di RTX 4060; ini jalur prediksi CT, bukan Ollama. Output reference 1024×1024 uint16 dibandingkan worker lama: selisih maksimum 1 pada 126 dari 1.048.576 piksel untuk jalur compiled. Belum merupakan penerimaan ilmiah atau exact match. |
| Kompatibilitas model | Trusted checkpoint lulus pada runtime Conda lama dalam 9.331 detik dan venv staging baru dengan dependency CUDA terkunci dalam 8.367 detik. Batas GPU 5 GiB, virtual address 24 GiB, cgroup RAM 4 GiB dan swap nol. Ini tidak menyatakan model arbitrer atau bobot 10 GiB pasti dapat dimuat. |
| Next.js | Suite final source 21 tes, check dan build lulus. Preview publik terproteksi juga diuji dengan login Laravel nyata kedua role pada 1366/768/390 px. Model asli selesai direct upload/resume, validasi, GPU compatibility dan publish nonaktif. Provider LLM tetap disabled; UI tidak membuktikan kualitasnya. |
| Flutter | Suite final source 251 tes, analyze dan build JavaScript web lulus. Pemeriksaan browser 390 px menguji mobile web Next.js; belum merupakan UAT aplikasi Flutter pada perangkat fisik. |

Pemeriksaan akhir GitHub melihat main tetap `29348144` dan dua workflow develop
sukses pada baseline `1ceedb5`, bukan source fitur baru. Native API Vercel
memverifikasi preview READY dengan metadata source `4f971be`, root `fe_web`,
dan API staging terisolasi. Model tetap nonaktif; promosi GitHub menunggu variable
API branch karena Actions Variables API ditolak 403. Detail transfer publik,
backup/restore dan batas verifikasi ada di
[DEPLOYMENT_CHECKPOINT.md](DEPLOYMENT_CHECKPOINT.md).
Runtime staging baru awalnya tidak mendeteksi GPU saat hanya memakai
TensorFlow base. Setelah memasang dependency resmi `tensorflow[and-cuda]`
dengan hash terverifikasi, GPU terdeteksi dan uji child dengan checkpoint
terverifikasi lulus. Penerimaan publik/staging, toleransi ilmiah dan kualitas
provider tetap harus dicatat terpisah sebelum promosi produksi. Pemeriksaan SSH
akhir kembali tidak melihat device node, PCIe atau modul Hailo; Ollama 0.11.4
aktif tanpa model yang sedang dimuat setelah probe sebelumnya selesai.

Sumber jawaban kurang tepat perlu diperiksa pada kapasitas model distil kecil,
kuantisasi, konteks/prompt, anggaran reasoning dan grounding. Kecepatan CPU
yang terukur tidak membuktikan penyebab kualitas tersebut. Jangan membeli
Hailo-8 dengan harapan Ollama DeepSeek otomatis lebih cepat atau lebih pintar.
