# Checkpoint deployment — 14 Oktober 2026

Implementasi Tasks 1–7 dan perbaikan review sudah selesai di branch `develop`
lokal. Staging Laravel/TUF dan preview Next.js sudah berjalan; promosi branch
GitHub, aktivasi model untuk produksi, dan aktivasi LLM belum diterima.
Dokumen ini memperbarui checkpoint persiapan sebelumnya, bukan persetujuan rilis
produksi. Source aplikasi yang dideploy adalah
`4f971bef4c5fd9b11791ce702c8fb4a975161ea8`. Commit dokumentasi berikutnya tidak
mengubah source aplikasi yang diperiksa.

## Source dan review

Perbaikan `dc7334b` menutup seluruh finding Important I1–I4 dan Minor M1–M3:
recovery intent unggahan, retry availability, proteksi penghapusan akun pemilik,
paginasi unggahan lama, identitas model historis, respons pemilihan yang basi,
dan grounding status uploaded. Scoped review menyetujui perbaikan tersebut.
Hasil runner yang sudah diperiksa: 146 Python, 392 Laravel/1.955 asersi,
251 Flutter, dan 21 Next.js; analyze/check serta build web JavaScript/Next lulus.
Ini hasil pengujian source, bukan exact-commit CI GitHub atau UAT fisik Flutter.

Cutover aktual menemukan bahwa matcher Host Caddy mengembalikan body kosong
dengan status 200 ketika menerima hostname ngrok. `4f971be` mengganti selector
dua public site menjadi `:8003`, dengan `bind 127.0.0.1` tetap eksplisit. Regresi
Caddy nyata RED/GREEN dan tujuh pemeriksaan konfigurasi lulus; review terpisah
menyetujui perubahan kecil ini. Body kosong tidak dihitung sebagai health API.

Minor yang ditunda tetap tercatat: migrasi recovery tidak mendukung pengulangan
down/up kedua pada tabel kosong, Node module metadata, Flutter Wasm dry-run,
peringatan target GSAP, dan perluasan tes workflow `if: always()`. Rollback
deployment mempertahankan schema recovery dan metadata unggahan; jangan memakai
migration down saat baris unggahan masih dipertahankan.

## Runtime dan preview aktual

| Komponen | Kondisi terverifikasi |
|---|---|
| Laravel Raspi | `/home/jihyo/deepct-staging/app`, database `deepct_staging`, APP_KEY/storage/cache/akun/antrean tersendiri; API, CT queue, scheduler dan gateway aktif. |
| Model TUF | `/home/jihyo-yue/deepct-model-staging`, satu Uvicorn lewat Unix socket, venv CUDA terkunci, root `deepct-models`, state dan bearer staging terpisah. |
| Next.js | Project Vercel `deepct-web`, Root Directory `fe_web`, deployment preview `dpl_4TEKayErjPpq4pRE8dKGv5knbUmK` READY; metadata API deployment mencatat SHA source di atas dan ref develop. |
| Otorisasi aktual | Login admin/user 200, kontrol unggah admin 200/user 403/anonim 401, HttpOnly/Secure cookie; assistant disabled pada kedua role. |
| Layout aktual | Browser preview pada 1366/768/390 px memeriksa kedua role, tidak ada overflow horizontal dan tombol kirim AI tetap disabled. |
| Legacy | HTTPS API/catalog lama tetap mengembalikan JSON 200; worker CT TUF PID 3743 tidak dihentikan atau diganti. |

Preview terlindungi Vercel:
https://deepct-f8duozruu-fajrians-projects-35dd060a.vercel.app

API staging eksplisit:
`https://zestfully-usable-pledge.ngrok-free.dev/staging/api`.
Jalur `/api` pada hostname tersebut tetap API legacy. TUF publik hanya membuka
jalur kapabilitas `/registry/uploads/*`; katalog, management dan prediksi baru
tetap private melalui NetBird. Tidak ada bearer kontrol di klien.

Perlindungan Vercel diperiksa dengan fasilitas bypass CLI pemilik yang normal,
tanpa OAuth baru atau mematikan proteksi project. Akun aplikasi staging adalah
akun sintetis terpisah. Operator dapat mengelolanya melalui akses SSH staging;
password, cookie dan capability tidak dimasukkan dalam source/artifact publik.

ngrok terpasang versi 3.39.11 tidak mendukung PUT endpoint pada agent API (405).
Cutover memakai legacy DELETE/POST untuk URL statis yang sama, dengan konfigurasi
upstream lama dicadangkan. Parameter `bind_tls` yang ditolak agent telah dihapus
dari helper; default HTTPS diperiksa aktual. Cutover sempat memerlukan rollback,
dan endpoint lama berhasil dipulihkan tanpa restart worker CT.

Setelah agent Raspi tersambung ulang, upstream kembali ke port 8000 dan prefix
staging hilang. Timer milik staging sekarang merekonsiliasi URL existing setiap
menit ke gateway sehat 8003, atau fallback ke legacy sehat 8000. Kedua timer
aktif dan oneshot success; pemulihan prefix HTTPS diperiksa. Ini bukti recovery
route pada proses berjalan, bukan uji physical reboot atau jaminan tanpa jeda.
Helpers dan unit timer disertakan dalam paket pemulihan cloud, dan tersimpan pada
masing-masing direktori staging server.

## Uji model dan transfer nyata

Trusted checkpoint `ginet-tcd-revisi/1.0.0` berukuran **87.796.792 byte** dengan
SHA256 `255fc3d26f8579deafa6312e7e041584a9c113e5ea51517a57059faaccbfe345`.
Model original tidak ditimpa. Metadata/otorisasi melalui Laravel; bytes langsung
ke TUF, tanpa diteruskan melalui Raspi atau fungsi Vercel.

Empat MiB pertama dipakai untuk pemeriksaan boundary gateway lokal dengan
kapabilitas nyata: tepat 4 MiB diterima, 4 MiB + 1 ditolak 413 tanpa perubahan
offset, capability salah ditolak 401. Sisa **83.602.488 byte** dikirim browser
melalui HTTPS TUF aktual. Unggahan dijeda pada offset 12.582.912, halaman dimuat
ulang, file dipilih/di-hash kembali, lalu dilanjutkan hingga offset akhir lengkap.
Jangan menyebut seluruh 87.796.792 byte sebagai transfer HTTPS browser.

DevTools tidak mengembalikan payload Blob melalui `postDataBuffer`; satu asersi
instrumentasi awal gagal setelah transfer selesai. Script penyelesaian terpisah
memeriksa validasi SHA/HDF5, uji GPU aktual dalam **12,008 detik** dan publish
nonaktif melalui UI preview. State akhir `ready_for_activate`, `published=true`;
flag aktif Laravel/TUF tetap false. Transfer besar tidak diulang untuk mengatasi
keterbatasan instrumen tersebut.

Probe browser tambahan 4.194.305 byte membuktikan dua request HTTPS berukuran
4.194.304 dan 1 byte, tanpa cookie aplikasi pada transport TUF. Offset dan status
200 cocok. Probe ini memakai fixture sintetis, dibatalkan setelah selesai, tidak
divalidasi sebagai model ilmiah dan tidak dipublikasikan. Metadata kepemilikannya
tetap dipertahankan.

Compatibility GPU memakai RTX 4060, budget GPU 5 GiB/virtual address 24 GiB,
cgroup RAM 4 GiB/swap nol/TasksMax128. Verifikasi akhir melihat GPU 1.425 MiB
terpakai dan 6.384 MiB kosong. Proses notebook yang sudah diidentifikasi sebelumnya
dihentikan hanya setelah instruksi eksplisit pengguna; worker CT legacy tetap
aktif. Compatibility tidak membuktikan setiap model 10 GiB dapat dimuat.

Parity compiled terhadap worker legacy mempertahankan preprocessing dan output
1024×1024 uint16. Selisih maksimum 1 pada 126 dari 1.048.576 piksel; toleransi
ilmiah belum disetujui. Uji GPU tidak mengizinkan aktivasi produksi otomatis.

## Unduhan besar bertanda tangan

Empat TIFF valid sintetis digunakan hanya untuk uji byte transport hasil milik
akun staging, bukan hasil prediksi GPU. BFF preview mengembalikan redirect 307
ke `/staging/api/downloads/predictions/1/results`, tanpa kehilangan prefix.
ZIP **8.391.066 byte** diterima langsung dari endpoint Raspi; ukuran dan SHA256
keempat TIFF cocok. Signature diubah/kedaluwarsa ditolak 403 dan akun lain 404.
Record serta model fixture sintetis dihapus setelah pemeriksaan; token sementara
kedua akun dicabut.

Percobaan pertama mencapai timeout klien 30 detik saat menerima ZIP. Uji yang
sama lulus dengan anggaran transfer 180 detik. Anggaran tersebut hanya pada
runner audit, bukan perubahan timeout aplikasi atau bukti throughput produksi.

## Backup terisi dan restore

Backup hanya untuk staging; tidak membaca atau mereset database produksi.
SQL dan file/config/state/weights disalin penuh ke direktori cloud privat dan
checksum-nya dibandingkan dengan sumber. Backup privat mengandung credential
staging dan tidak termasuk paket unduhan pemulihan/source.

| Backup | Ukuran | SHA256 |
|---|---|---|
| SQL Raspi | 55.288 byte | `7f3096a9856408a80ba89c22ad6d29b6a18705fb9d8acaec38a6376dcf9eb132` |
| File Raspi | 216.358 byte | `03b70368d29df614ed2c33586754c79947375cf2bd8631fda98435219507cefc` |
| File/model/state TUF | 81.269.950 byte | `377dd3298539a4691db3328ad7d9a38ea92b71add2d75d17b409657b1b7c6ce3` |

SQL direstore ke database baru `deepct_restore_populated_20261014`. Dump seluruh
data tabel cocok, termasuk 49 migrations, 2 users, 1 model, 2 model uploads,
0 analysis records, 0 conversations dan 0 personal access tokens. Restore file
ke direktori baru yang tidak dipakai layanan mencocokkan 173 file Raspi dan
25 file TUF. Catalog registry hasil restore dapat dibaca, bobot cocok SHA,
dua sesi upload pulih, tidak ada model aktif dan inferensi nonaktif ditolak.
Restore tidak memuat GPU atau memodifikasi path aplikasi live.

Dependency venv/vendor direproduksi dari lock; backup ini tidak menyertakan
binary dependency atau model produksi. Service hasil restore belum dijalankan
dan physical reboot belum diuji. Keberhasilan data/file/catalog restore tidak
diklaim sebagai full disaster-recovery rehearsal.

## Gate yang masih terbuka

1. GitHub menolak baca/tulis Actions Variables dengan 403
   `Resource not accessible by integration`. Operator perlu menetapkan
   **DEVELOP_API_BASE_URL** dan **STAGING_API_BASE_URL** ke URL staging di atas.
   Jangan mengubah variable API produksi. Belum ada konfirmasi pengguna bahwa
   perubahan ini selesai, sehingga push yang dapat memicu preview dengan
   variable lama ditahan.
2. Remote develop masih `1ceedb5`, staging `96dc56b`, main `2934814` pada pemeriksaan
   akhir. Dua workflow develop sukses pada `1ceedb5`, bukan CI source fitur baru.
   Setelah variable benar, push develop, tunggu CI SHA tersebut, lalu staging.
   Promosi main tetap memerlukan gate UAT yang terpisah.
3. Kelima kasus kualitas DeepSeek R1 1.5b gagal. LLM tetap disabled; tidak ada
   penggantian/download model atau aktivasi provider diam-diam. Audit Hailo ada
   di [AI_HARDWARE_AUDIT.md](AI_HARDWARE_AUDIT.md).
4. Penerimaan ilmiah parity, arbitrary-model acceptance, UAT Flutter perangkat
   fisik, branch protection/environment approval, serta uji restore layanan dan
   physical reboot belum diterima. Tidak ada hasil fixture yang menggantikannya.
5. Quota akun ngrok aktual belum diketahui. Dokumentasi Free yang diperiksa
   mencantumkan 1 GB outbound/bulan dan 20.000 request/bulan. URL statis tidak
   membuktikan kesiapan traffic besar berkelanjutan.
6. Penyimpanan draft setup cloud sebelumnya ditolak `CONFLICT/stale_base`.
   Tidak dicoba ulang pada sesi ini. Script, source Git bundle, laporan dan ledger
   dipaketkan sebagai recovery; penyimpanan/publikasi environment belum diklaim.

Instruksi operasi dan rollback: [RELEASE.md](RELEASE.md). Rollback mempertahankan
metadata/ownership unggahan dan schema recovery; ingress dapat dikembalikan ke
upstream lama tanpa menghentikan worker produksi.
