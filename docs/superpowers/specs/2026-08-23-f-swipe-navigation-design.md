# Bagian F — Navigasi swipe, dan konfirmasi sebelum keluar

**Tanggal:** 23 Agustus 2026
**Status:** rancangan disetujui, belum dikerjakan

Diajukan 22 Agustus 2026 di tengah pengerjaan bagian B2, dan dicatat sebagai
ROADMAP §13.

## Dua hal, dan salah satunya bug

**Menggeser jari ke kiri atau kanan tidak melakukan apa pun hari ini.** Ia
seharusnya berpindah antar tab.

**Gestur kembali di Dashboard langsung melempar orang ke landing page tanpa
bertanya apa pun.** Sudah diperiksa: tidak ada `PopScope`, `WillPopScope`,
maupun penangan gestur sama sekali di `user_shell.dart` atau `admin_shell.dart`
— gestur kembali Android tidak dicegat oleh apa pun. Salah geser satu kali
berarti keluar dari konsol tanpa peringatan.

## F1 — Geser kiri/kanan berpindah tab

`UserSection` punya enam entri berurutan: Dashboard, New Analysis,
Results & History, Model Training, My Activity, Messages. `AdminSection` punya
tujuh setelah tab Training dihapus di bagian D.

Geser ke kiri maju satu, ke kanan mundur satu, dan berhenti di ujung — tidak
melingkar. Melingkar berarti satu geseran dari Messages mendarat di Dashboard,
yang terasa seperti kehilangan tempat.

### `GestureDetector`, bukan `PageView`

Ini keputusan yang menentukan, dan alasannya adalah tabrakan gestur.

Ada konten yang **juga** menggulung horizontal: tabel metrik training memakai
`SingleChildScrollView(scrollDirection: Axis.horizontal)`, dan beberapa tabel
admin sama. `PageView` merebut gestur horizontal sebelum anaknya sempat
memintanya, sehingga menggeser di atas tabel akan berpindah tab alih-alih
menggulung tabelnya.

`GestureDetector` dengan `onHorizontalDragEnd` tidak begitu: scrollable di dalam
memenangkan arena gestur Flutter, jadi geseran di atas tabel menggulung
tabelnya dan geseran di tempat lain sampai ke shell. Itu perilaku yang benar,
dan ia gratis.

Ambang batas: geseran diabaikan bila kecepatannya di bawah 200 px/detik, supaya
sentuhan yang sedikit meleset tidak memindahkan tab.

### `SelectionArea`

Bagian A memasang `SelectionArea` di badan kedua shell. Ia memulai seleksi
dengan **tekan-lama**, bukan geser, jadi keduanya tidak bertabrakan secara
teori. **Itu harus dibuktikan di perangkat, bukan diasumsikan** — keduanya
bekerja pada pohon widget yang sama.

## F2 — Gestur kembali punya dua tahap

| Di mana | Yang terjadi |
|---|---|
| Tab mana pun selain Dashboard | Kembali ke Dashboard, satu langkah |
| Dashboard | Konfirmasi keluar |

Itu pola Android yang sudah dikenal orang, dan itu persis yang diminta.

Dipasang dengan `PopScope(canPop: false, onPopInvokedWithResult: ...)` di kedua
shell. `canPop: false` selalu, karena kedua cabang menangani gesturnya sendiri
— membiarkannya `true` di Dashboard akan mengembalikan perilaku sekarang, yaitu
keluar tanpa bertanya.

Konfirmasinya memakai `_confirmLogout()` yang sudah ada di kedua shell, jadi
gestur dan tombol Sign out berakhir di dialog yang sama. Tidak ada kalimat
kedua yang bisa menyimpang dari yang pertama.

**Tombol Sign out tetap ada.** Kalau gestur salah tangkap, orang harus tetap
punya jalan keluar yang pasti.

## Cara menguji

**Test widget** bisa membuktikan:

- geser ke kiri di Dashboard mendarat di New Analysis;
- geser ke kanan di Dashboard tidak ke mana-mana;
- gestur kembali dari Messages mendarat di Dashboard, bukan keluar;
- gestur kembali di Dashboard memunculkan dialog, dan tidak ada `Navigator.pop`
  yang terjadi sebelum dialog itu dijawab.

Yang terakhir itu yang paling penting: ia adalah bug-nya.

**Yang tidak bisa dijangkau test:** apakah gestur tepi layar Android sungguhan
sampai ke `PopScope`, dan apakah seleksi teks masih bekerja di sebelahnya.
Keduanya menuntut perangkat.

## Risiko

**F menyentuh dua shell yang setiap layar hidup di dalamnya.** Perbaikannya
kecil, tetapi kalau gestur kembali salah tangkap, seseorang bisa terjebak tidak
bisa keluar sama sekali. Itu alasan tombol Sign out tetap tinggal, dan alasan
uji di perangkat bukan pelengkap.

**Perilaku gestur kembali berbeda antar peluncur Android.** Sebagian
menyerahkannya ke aplikasi, sebagian menanganinya sendiri. `PopScope` adalah
API yang tepat, tetapi apa yang benar-benar terjadi hanya terlihat di
perangkat.

## Yang bukan bagian F

- **E** — preview dataset training.
- Navigasi swipe di landing page. Ia bukan konsol dan tidak punya tab.
