# Bagian F — Navigasi swipe dan konfirmasi keluar: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menggeser jari berpindah tab, dan gestur kembali tidak lagi melempar orang keluar dari konsol tanpa bertanya.

**Architecture:** Sebuah `GestureDetector` di badan tiap shell memindahkan `_section` satu langkah, dan sebuah `PopScope` mencegat gestur kembali: dari tab mana pun ia pulang ke Dashboard, dan dari Dashboard ia memanggil `_confirmLogout()` yang sudah ada.

**Tech Stack:** Flutter.

## Global Constraints

- **`GestureDetector`, bukan `PageView`.** Ada konten yang juga menggulung horizontal — tabel metrik training, beberapa tabel admin. `PageView` merebut gestur sebelum anaknya sempat memintanya; scrollable di dalam menang melawan `GestureDetector`, dan itu perilaku yang benar.
- **Tidak melingkar.** Geseran berhenti di ujung. Melingkar berarti satu geseran dari entri terakhir mendarat di Dashboard, yang terasa seperti kehilangan tempat.
- **Ambang 200 px/detik**, supaya sentuhan yang sedikit meleset tidak memindahkan tab.
- **`canPop: false` selalu**, di kedua cabang. Membiarkannya `true` di Dashboard mengembalikan bug yang sedang diperbaiki.
- **Tombol Sign out tetap ada.** Kalau gestur salah tangkap, harus tetap ada jalan keluar yang pasti.
- **Konfirmasi memakai `_confirmLogout()` yang sudah ada**, supaya gestur dan tombol berakhir di dialog yang sama.
- **Dasar sebelum F:** backend 272 test, Flutter 168 test, `flutter analyze` bersih.

---

### Task 1: Perpindahan tab dan gestur kembali di shell periset

**Files:**
- Modify: `fe/lib/screens/user/user_shell.dart`
- Test: `fe/test/shell_navigation_test.dart` (baru)

**Interfaces:**
- Produces: `UserShell` berpindah `_section` pada geseran horizontal, dan mencegat gestur kembali dengan `PopScope`.

- [ ] **Step 1: Tulis test yang gagal**

`fe/test/shell_navigation_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/screens/user/user_shell.dart';

/// The section order a swipe walks through.
///
/// Pinned as a test because the swipe steps one place along this list, so
/// reordering the enum silently reorders navigation.
void main() {
  test('the researcher sections are in the order a swipe walks', () {
    expect(UserSection.values.first, UserSection.dashboard);

    expect(
      UserSection.values.map((s) => s.name).toList(),
      ['dashboard', 'analysis', 'history', 'training', 'activity', 'messages'],
    );
  });

  test('stepping stops at both ends rather than wrapping', () {
    // Wrapping would put one swipe from the last entry onto the Dashboard,
    // which reads as losing your place rather than moving.
    expect(nextSection(UserSection.dashboard, -1), UserSection.dashboard);
    expect(nextSection(UserSection.messages, 1), UserSection.messages);
  });

  test('stepping moves exactly one place', () {
    expect(nextSection(UserSection.dashboard, 1), UserSection.analysis);
    expect(nextSection(UserSection.history, -1), UserSection.analysis);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/shell_navigation_test.dart`
Expected: FAIL — `nextSection` belum ada.

- [ ] **Step 3: Tulis `nextSection`**

Di `fe/lib/screens/user/user_shell.dart`, sebagai fungsi tingkat atas di bawah
`enum UserSection`:

```dart
/// One step along the section list, clamped at both ends.
///
/// Clamped rather than wrapped: a swipe from the last entry landing on the
/// Dashboard reads as losing your place, not as moving.
UserSection nextSection(UserSection from, int step) {
  final index = UserSection.values.indexOf(from) + step;

  if (index < 0 || index >= UserSection.values.length) return from;

  return UserSection.values[index];
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/shell_navigation_test.dart`
Expected: PASS, 3 test.

- [ ] **Step 5: Geseran memindahkan tab**

Di `_UserShellState.build`, bungkus badan yang sudah ada. Bentuknya sekarang:

```dart
      body: SelectionArea(
        child: SafeArea(
          bottom: false,
          child: Row(
```

Menjadi:

```dart
      body: SelectionArea(
        // GestureDetector rather than a PageView: the metrics table and some
        // admin tables scroll horizontally too, and a PageView takes the
        // gesture before its child can ask for it. An inner scrollable wins
        // the arena against this, which is exactly what we want.
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;

            // Below this it was a tap that wandered, not a swipe.
            if (velocity.abs() < 200) return;

            // Dragging leftwards moves forward through the list.
            final next = nextSection(_section, velocity < 0 ? 1 : -1);
            if (next != _section) setState(() => _section = next);
          },
          child: SafeArea(
            bottom: false,
            child: Row(
```

dengan satu `)` tambahan di penutup `body:`.

- [ ] **Step 6: Gestur kembali punya dua tahap**

Bungkus `Scaffold` yang dikembalikan `build` dengan `PopScope`:

```dart
    return PopScope(
      // Always false: both branches handle the gesture themselves. Leaving it
      // true on the Dashboard restores the bug this is fixing — a mis-swipe
      // dropping someone onto the landing page with no warning.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // From anywhere else, back means home — one step, the way Android
        // has always behaved.
        if (_section != UserSection.dashboard) {
          setState(() => _section = UserSection.dashboard);
          return;
        }

        // From home it means leaving, and leaving is worth asking about.
        // The same dialog the Sign out button opens, so the two cannot drift.
        _confirmLogout();
      },
      child: Scaffold(
        // ... isi yang sudah ada, tidak berubah ...
      ),
    );
```

- [ ] **Step 7: Analisa**

Run: `cd fe && flutter analyze`
Expected: bersih.

Bila `onPopInvokedWithResult` tidak dikenali, versi Flutter di sini lebih lama
dari yang mengenalkannya; pakai `onPopInvoked: (didPop) { ... }` dan **jangan**
kembali ke `WillPopScope`, yang sudah usang.

- [ ] **Step 8: Commit**

```bash
git add fe/lib/screens/user/user_shell.dart fe/test/shell_navigation_test.dart
git commit -m "Let a swipe move between tabs, and stop back from leaving without asking"
```

---

### Task 2: Hal yang sama di shell admin

**Files:**
- Modify: `fe/lib/screens/admin/admin_shell.dart`
- Test: `fe/test/shell_navigation_test.dart` (ditambah)

**Interfaces:**
- Consumes: pola dari Task 1.
- Produces: `nextAdminSection(AdminSection from, int step)`.

- [ ] **Step 1: Tambahkan test**

Tambahkan ke `fe/test/shell_navigation_test.dart`:

```dart
  test('the admin sections keep the Dashboard first', () {
    // The back gesture goes home, and home is whatever sits first.
    expect(AdminSection.values.first, AdminSection.dashboard);
  });

  test('admin stepping clamps and moves one place', () {
    expect(nextAdminSection(AdminSection.dashboard, -1), AdminSection.dashboard);
    expect(nextAdminSection(AdminSection.dashboard, 1), AdminSection.users);
    expect(
      nextAdminSection(AdminSection.values.last, 1),
      AdminSection.values.last,
    );
  });
```

Tambahkan `import 'package:fe/screens/admin/admin_shell.dart';` di bagian atas
berkas.

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/shell_navigation_test.dart`
Expected: FAIL — `nextAdminSection` belum ada.

- [ ] **Step 3: Tulis `nextAdminSection`**

Di `fe/lib/screens/admin/admin_shell.dart`, di bawah `enum AdminSection`:

```dart
/// One step along the section list, clamped at both ends.
///
/// Kept beside its own enum rather than made generic over both: a generic
/// version would take `List<T>` and an index and read worse than the two
/// three-line functions it replaced.
AdminSection nextAdminSection(AdminSection from, int step) {
  final index = AdminSection.values.indexOf(from) + step;

  if (index < 0 || index >= AdminSection.values.length) return from;

  return AdminSection.values[index];
}
```

- [ ] **Step 4: Terapkan pola yang sama di `build`**

Bungkus badan dengan `GestureDetector` dan `Scaffold` dengan `PopScope`, persis
seperti Task 1 Step 5 dan 6, dengan tiga perbedaan: `nextAdminSection`
menggantikan `nextSection`, `AdminSection.dashboard` menggantikan
`UserSection.dashboard`, dan komentar `GestureDetector` cukup ditulis sekali di
`user_shell.dart` — di sini rujuk saja.

Untuk `PopScope`:

```dart
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (_section != AdminSection.dashboard) {
          setState(() => _section = AdminSection.dashboard);
          return;
        }

        _confirmLogout();
      },
      child: Scaffold(
```

- [ ] **Step 5: Analisa dan seluruh test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 173 test lulus.

- [ ] **Step 6: Commit**

```bash
git add fe/lib/screens/admin/admin_shell.dart fe/test/shell_navigation_test.dart
git commit -m "Give the admin shell the same gestures"
```

---

### Task 3: Bangun, pasang, dan catat

**Files:**
- Modify: `CHANGELOG.md`, `ROADMAP.md`

- [ ] **Step 1: Verifikasi penuh**

```bash
cd fe && flutter analyze && flutter test && flutter build apk --release
```

- [ ] **Step 2: Pasang bila perangkat tersambung**

Run: `cd fe && flutter devices`

Bila `SM A325F` muncul, pasang dan buktikan ia berjalan:

```bash
flutter install --release -d RR8RC06T1LY
```

Bila tidak muncul, katakan begitu dan lanjutkan. Perangkatnya terputus di
tengah sesi sebelumnya; itu bukan alasan menahan sisa pekerjaan.

- [ ] **Step 3: `CHANGELOG.md`**

Sebutkan bahwa separuh F adalah **bug**, bukan fitur: gestur kembali di
Dashboard melempar orang ke landing page tanpa bertanya, dan tidak ada
`PopScope` maupun penangan gestur sama sekali di kedua shell sebelum ini.

Sebutkan juga kenapa `GestureDetector` dan bukan `PageView`.

- [ ] **Step 4: `ROADMAP.md`**

Centang §13 bila suite hijau, dengan catatan bahwa gestur tepi layar Android
sungguhan dan hidup berdampingannya dengan `SelectionArea` **belum dilihat di
perangkat** — keduanya hanya terlihat di sana.

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md ROADMAP.md
git commit -m "Record part F"
```

---

## Catatan untuk pelaksana

**Test di sini menguji urutan dan langkah, bukan gestur.** `flutter test` tidak
bisa membangkitkan gestur tepi layar Android, dan itulah tepatnya jalur yang
bug-nya ada. Yang bisa diuji — bahwa daftar seksinya berurutan dengan Dashboard
di depan, dan bahwa melangkah berhenti di ujung — adalah yang membuat gesturnya
mendarat di tempat yang benar ketika ia memang sampai.

**Sisanya menuntut perangkat**, termasuk apakah `SelectionArea` dari bagian A
masih bisa menyeleksi teks di sebelah `GestureDetector` yang baru. Keduanya
bekerja pada pohon widget yang sama.
