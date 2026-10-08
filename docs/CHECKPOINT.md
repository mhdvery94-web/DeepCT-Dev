# Checkpoint proyek — 9 Oktober 2026

## Kontrak dan keadaan yang sudah diterima

- Admin/user memakai prediksi saja; training telah dihapus di frontend, backend,
  skema database dan berkas aplikasi lama.
- News memakai editor artikel serta pengelolaan gambar/video independen.
  Web memiliki kontrol lebih lembut dan layout responsif.
- Kode produksi 49da8eb, dokumentasi sebelumnya bbe1e39.
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

Berikutnya commit/push main, pantau workflow, lalu git pull --ff-only.
Catat commit/workflow serta hasil aktual di blok ini; jangan mengulang audit
atau pemeriksaan yang sudah lulus tanpa perubahan/failure baru.

## Sinkronisasi lokal

Workspace /workspace/DeepCT-Dev adalah checkout lokal environment Codex.
Laptop Vivobook 100.85.5.67 belum berhasil diakses: percobaan SSH terbaru
menjawab Connection refused. Snapshot environment menunjukkan VPN belum
terkonfigurasi dan TCP grants kosong. Jangan menyebut git pull workspace
sebagai bukti laptop sudah sinkron. Jika akses tersedia, periksa branch/status/
commit laptop terlebih dahulu dan pertahankan perubahan lokalnya.
