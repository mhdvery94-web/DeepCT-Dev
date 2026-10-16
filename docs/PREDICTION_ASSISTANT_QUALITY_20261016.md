# Uji asisten prediksi pada GPU TUF

Uji aktual menjalankan 40 kasus sintetis per model pada Ollama 0.11.4 di TUF RTX 4060 Laptop 8 GB. Semua 80 jawaban akhir ditinjau satu per satu. Kedua model belum lulus gerbang jawaban bebas; tidak ada aktivasi otomatis. Asisten staging tetap memakai mode metadata: model memilih topik, Laravel menyusun fakta dari bukti milik pengguna dan SOP terkurasi.

| Model | Kasus dijalankan | Lolos aturan leksikal | Tinjauan manual: lengkap / parsial / gagal | Median waktu |
| --- | --- | --- | --- | --- |
| DeepSeek R1 7B | 40 | 13 | 16 / 9 / 15 | 4,273 detik |
| Qwen2.5 7B Instruct Q4_K_M | 40 | 14 | 19 / 10 / 11 | 4,258 detik |

Angka manual berlaku untuk kasus dan kriteria ini, bukan tingkat akurasi umum atau peringkat kecerdasan. Aturan leksikal memiliki negatif dan positif palsu; keputusan tidak didasarkan pada jumlah kecocokan teks. Contohnya, jawaban benar berbentuk kalimat dapat gagal pola angka, sementara jawaban yang membolehkan data sintetis menjadi ground truth dapat lolos pencarian kata.

Kegagalan penting yang diamati:

- DeepSeek menyamakan MAE yang dibulatkan menjadi nol dengan piksel identik, mengarang baseline nol/tak terhingga saat pengukuran baseline gagal, dan menyatakan hasil siap dipakai secara ilmiah tanpa ambang atau persetujuan peneliti.
- Qwen menyatakan MAE 12,5 lebih rendah daripada baseline 10 dan membalik arti selisih negatif. Kedua model menganggap versi dokumen SOP sebagai versi model historis yang tidak tersedia, menyamakan snapshot dengan status langsung, dan mengikuti instruksi untuk mengarang MAE 999.
- Respons lintas pemilik hanya menggunakan sumber sintetis yang diizinkan. Kekeliruan atribusi bukan bukti bahwa otorisasi backend dapat dilewati; otorisasi diuji terpisah lewat API.

Keduanya memakai profil yang sama: `think=false`, konteks 16384, keluaran maksimum 1024 token, temperatur 0,2, seed 17, empat thread, `keep_alive=0`. Ini menguji R1 dalam profil penerapan tanpa thinking, bukan seluruh kemampuan penalarannya. Prompt dan sumber sintetis dibekukan bersama skrip `0b8a341`; tidak ada byte TIFF privat atau reasoning internal yang diekspor.

Pengamatan GPU menangkap konteks 16384, residensi VRAM 5.929.203.712 byte dari ukuran model 6.708.066.304 byte, dan puncak utilisasi GPU 100% untuk kedua model. Perbandingan ukuran ini menggambarkan penempatan memori, bukan akurasi maupun persentase komputasi. Semua kasus memakai shared GPU lease, syarat VRAM kosong 6144 MiB, dan unload terverifikasi. Sesudah uji, model Ollama tidak lagi dimuat, penanda lease kosong, VRAM kembali 1425 MiB terpakai / 6384 MiB kosong, dan proses CT lama PID 3743 tetap berjalan.

Paket bukti pemulihan menyimpan jawaban akhir, keputusan manual per kasus, waktu, identitas model/runtime, checksum skrip/korpus, pengamatan GPU dan verifikasi pascauji. Tidak ada konfigurasi atau data produksi yang diubah oleh eksperimen ini. Kesiapan model CT secara ilmiah dan uji Android fisik merupakan gerbang yang berbeda.
