# Checkpoint proyek — 9 Oktober 2026

## Kontrak dan keadaan yang sudah diterima

- Admin/user memakai prediksi saja; training telah dihapus di frontend, backend,
  skema database dan berkas aplikasi lama.
- News memakai editor artikel serta pengelolaan gambar/video independen.
  Web memiliki kontrol lebih lembut dan layout responsif.
- Baseline prediksi/media 49da8eb, dokumentasi sebelumnya bbe1e39.
- Next workflow 37828069039 dan Release 37828069000 selesai sukses: tes,
  Web/Android/Linux/iOS/macOS, deployment Pi/Vercel dan artifact.
- Backend 329 tes/1.381 asersi, Flutter 227 tes dan analyze bersih,
  browser 51, Pi smoke 39, HTTPS publik 25 semuanya lulus.
- Backup Pi storage/backups/db-20261009-015729.sql.gz dibuat sebelum migrasi
  retirement; migrasi dan app:cleanup-retired-data berhasil.
- UAT ilmiah worker GPU nyata belum diterima; browser/suite memakai fixture/mock.

## Pekerjaan sesi pembersihan saat ini

Pengguna meminta hanya README.md di root, dokumentasi aplikasi diringkas di
docs, AGENTS/CLAUDE dan bahan nonaplikasi dikeluarkan dari GitHub, lalu git pull
untuk sinkronisasi local. Pertanyaan LLM dijawab melalui rancangan, bukan
implementasi provider/UI baru.

Folder stitch/proposal/models-ai/Images/.kilo dihapus dari repo. Aset logo/icon
aktif tetap di frontend dan identik dengan salinan root yang dihapus.
Script inference tetap pada lokasi aslinya; runtime/data/migration tidak
dipindahkan. Next agentRules=false mencegah Markdown agent dibuat ulang.
Dokumen lama digabung menjadi architecture/API/operations/development/LLM/
checkpoint; riwayat rinci tetap tersedia di Git commit bbe1e39.

Konsolidasi selesai: tujuh Markdown aktif, sekitar 550 baris, link valid, folder lama
tidak ada, aset frontend utuh dan script inference tidak berubah. Lint/
TypeScript, tes web dan build produksi Docker lulus. next dev berhasil dan
tidak membuat AGENTS.md kembali. Backend hanya menerima pembaruan komentar;
logika runtime/database tidak berubah pada sesi ini.

Pembersihan **923bc86 sudah dipush main**. GitHub root telah diverifikasi hanya
berisi komponen aplikasi/config dan README; docs memuat enam dokumen di atas.
`git pull --ff-only` di workspace berhasil dengan Already up to date, dan
HEAD/origin/main sama. **Next 37833767080 dan Release 37833766927 selesai sukses
seluruhnya**, termasuk backend 329/1.381, Flutter 227/analyze bersih,
Web/Android/Linux/iOS/macOS, deployment Pi/Vercel dan publikasi artifact.
Produksi 923bc86 melewati 39 smoke API Pi serta lima check health/web/aset HTTPS.
Dokumentasi hasil akhir dicatat dengan [skip ci]; kode produksi tidak berubah.

Pembersihan dan pull workspace selesai. Tidak ada pekerjaan konsolidasi yang
perlu diulang. Lanjutkan hanya permintaan baru, implementasi LLM bila diminta,
UAT GPU nyata atau sinkronisasi Vivobook setelah koneksi SSH tersedia.

## Sinkronisasi lokal

Workspace /workspace/DeepCT-Dev adalah checkout lokal environment Codex.
Laptop Vivobook 100.85.5.67 belum berhasil diakses: percobaan SSH terbaru
menjawab Connection refused. Snapshot environment menunjukkan VPN belum
terkonfigurasi dan TCP grants kosong. Jangan menyebut git pull workspace
sebagai bukti laptop sudah sinkron. Jika akses tersedia, periksa branch/status/
commit laptop terlebih dahulu dan pertahankan perubahan lokalnya.
