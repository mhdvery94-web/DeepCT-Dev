# 🔬 Rancang Bangun Platform Analisis Citra Neutron CT

Platform terintegrasi Web dan Mobile berbasis arsitektur Hybrid Cloud-NAS untuk analisis dan interpolasi citra Neutron CT (Computed Tomography) menggunakan Deep Learning.

---

## 🎯 Deskripsi Project

Sistem ini merupakan platform penelitian BRIN yang memungkinkan peneliti untuk melakukan interpolasi frame citra Neutron CT secara otomatis menggunakan model deep learning. Platform ini mengintegrasikan:

- **Frontend**: Aplikasi Web dan Mobile berbasis Flutter
- **Backend**: API RESTful berbasis Laravel 12
- **AI Engine**: Model TensorFlow/Keras yang di-deploy di Google Colab
- **Storage**: Hybrid Cloud-NAS untuk penyimpanan hasil analisis

---

## 🚀 Fitur Utama

### 1. **Pengunggahan Citra Medis/Material**
- Mendukung format gambar `.tif` 16-bit
- Drag-and-drop interface
- Validasi otomatis format file

### 2. **Interpolasi Frame Cerdas**
- Menghasilkan frame intermediate (T1) dari dua citra batas (T0 dan T2)
- Menggunakan model Machine Learning dengan metode interpolasi rekursif
- Akurasi tinggi dengan t=0.5 optimal

### 3. **Arsitektur Hybrid**
- Memisahkan penyimpanan lokal (NAS/Laravel) dengan komputasi berat (Google Colab/Cloud GPU)
- Skalabilitas tinggi dan efisien
- Keamanan data terjamin

### 4. **Akses Multi-Platform**
- Aplikasi Android native
- Web application responsive
- Dashboard berbasis role (Admin & User)

### 5. **Manajemen Terpusat**
- User management oleh admin
- Model deployment tracking
- History aktivitas pengguna
- Auto-delete hasil prediksi (1 hari)

---

## 🛠️ Stack Teknologi

| Komponen | Teknologi | Versi |
|----------|-----------|-------|
| **Frontend** | Flutter (Dart) | Latest |
| **Backend** | Laravel + Octane | 12.x |
| **Web Server** | RoadRunner | 2025.1.15 |
| **Database** | MySQL | 8.x |
| **AI/ML Engine** | TensorFlow/Keras | 2.x |
| **ML Deployment** | Google Colab/Kaggle + Ngrok | - |
| **Local Server** | Laragon | - |
| **Language** | PHP | 8.2+ |

---

## 📋 Persyaratan Sistem

### Backend (Laravel)
- PHP 8.2 atau lebih tinggi
- MySQL 8.0 atau lebih tinggi
- Composer
- Laragon (untuk Windows)

### Frontend (Flutter)
- Flutter SDK 3.0+
- Dart SDK 3.0+
- Android Studio / VS Code
- Chrome (untuk web development)

### AI Worker (Google Colab)
- Google Account
- Ngrok account (untuk tunnel)
- Model file: `generator(Salinan 3 Ginet TC-D_Revisi).h5`

---

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone <repository-url>
cd deepCT-gemini
```

### 2. Setup Backend (Laravel)
```bash
cd be
composer install
npm install
cp .env.example .env
php artisan key:generate
```

Konfigurasi `.env`:
```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=db_aict
DB_USERNAME=root
DB_PASSWORD=

# Server configuration
OCTANE_SERVER=roadrunner
CACHE_STORE=file

# Note: NGROK_API_URL sudah tidak digunakan
# Model endpoint di-manage via Admin UI → Model Management
```

Jalankan migration dan seeder:
```bash
php artisan migrate
php artisan db:seed
php artisan storage:link
```

**Start Server (Octane - Recommended):**
```bash
npm run octane
```

Server akan jalan di: `http://127.0.0.1:8000`

**Alternative (Development only):**
```bash
php artisan serve
```

Jalankan scheduler di terminal terpisah agar health check & token cleanup benar-benar berjalan:
```bash
php artisan schedule:work
```

### 3. Setup Frontend (Flutter)
```bash
cd fe
flutter pub get
flutter run -d chrome
```

Frontend menghubungi backend lewat domain ngrok yang tercantum di
`fe/lib/config/api_config.dart`. Pastikan tunnel-nya hidup (`ngrok http 8000`),
atau arahkan ke backend lokal tanpa mengedit file:
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

### 4. Setup AI Worker (Google Colab/Kaggle)
1. Buka notebook `models-ai/Evaluation_2_to_1_1kx1k_With_Logo.ipynb`
2. Upload model `generator(Salinan 3 Ginet TC-D_Revisi).h5`
3. Jalankan cell FastAPI server
4. Copy URL Ngrok yang dihasilkan
5. **Login sebagai admin** dan update endpoint via UI:
   - Admin Dashboard → Model Management → Edit Model → Update Endpoint URL
   - Sistem otomatis health check setelah update

---

## 👥 User Credentials (Default)

### Admin
- **Email**: admin@brin.go.id
- **Password**: admin123
- **Role**: Administrator

### User (Sample)
- **Email**: researcher@brin.go.id
- **Password**: user123
- **Role**: Researcher

---

## 📁 Struktur Direktori

```
deepCT-gemini/
├── be/                          # Backend Laravel
│   ├── app/
│   │   ├── Http/Controllers/    # API Controllers
│   │   ├── Models/              # Eloquent Models
│   │   └── Jobs/                # Queue Jobs
│   ├── database/
│   │   ├── migrations/          # Database Migrations
│   │   └── seeders/             # Database Seeders
│   └── routes/                  # API Routes
│
├── fe/                          # Frontend Flutter
│   ├── lib/
│   │   ├── screens/             # UI Screens
│   │   ├── widgets/             # Reusable Widgets
│   │   ├── services/            # API Services
│   │   └── models/              # Data Models
│   └── assets/                  # Images, Fonts
│
├── models-ai/                   # AI/ML Models
│   ├── *.h5                     # Model Files
│   └── *.ipynb                  # Jupyter Notebooks
│
├── stitch/                      # Design References
│   ├── landing_page/
│   ├── login_portal/
│   ├── admin_dashboard_models/
│   └── user_dashboard_prediction_results/
│
├── images/                      # BRIN Assets
│   ├── BRIN_Logo.ico
│   ├── BRIN.png
│   └── DL_neutron_xray_CT.ico
│
└── docs/                        # Documentation
    ├── README.md
    ├── ARCHITECTURE.md
    ├── API_DOCS.md
    ├── DESIGN.md
    ├── PRD.md
    ├── SETUP.md
    ├── TODO.md
    ├── CHANGELOG.md
    └── AI_EXPERIMENTS.md
```

---

## 📖 Dokumentasi Lengkap

### Root Documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - Arsitektur sistem dan flow diagram
- [API_DOCS.md](API_DOCS.md) - Dokumentasi API endpoint (35 endpoints + `/api/health`)
- [DESIGN.md](DESIGN.md) - Design system dan UI/UX guidelines
- [PRD.md](PRD.md) - Product Requirements Document
- [SETUP.md](SETUP.md) - Panduan instalasi detail
- [TODO.md](TODO.md) - Task list development (70% complete)
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [AI_EXPERIMENTS.md](AI_EXPERIMENTS.md) - Eksperimen dan solusi model AI
- [TESTING_RESULTS.md](TESTING_RESULTS.md) - Performance testing & benchmark
- [FASE3_DECISIONS.md](FASE3_DECISIONS.md) - Technical decisions FASE 3
- [FASE3_ROADMAP.md](FASE3_ROADMAP.md) - Development roadmap

### Backend Documentation (be/)
- [DATABASE_CLEANUP.md](be/DATABASE_CLEANUP.md) - Database structure analysis & recommendations
- [CHANGELOG.md](be/CHANGELOG.md) - Backend version history
- [README.md](be/README.md) - Backend specific setup

### Frontend Documentation (fe/)
- [README.md](fe/README.md) - Frontend specific setup
- [test_auth.md](fe/test_auth.md) - Authentication testing guide

---

## 🔑 Key Flows

### Flow 1: Researcher Upload & Prediction
1. User login ke sistem
2. Navigate ke dashboard upload
3. Upload 2 file `.tif` (T0 dan T2)
4. Klik "Run Prediction"
5. Sistem menggunakan interpolasi rekursif:
   - Tahap 1: T0 + T2 → T1 (frame 005)
   - Tahap 2: T0 + T1 → frame 004
   - Tahap 3: T1 + T2 → frame 006
6. Lihat hasil prediksi dengan metrics
7. Download hasil sebelum auto-delete (24 jam)

### Flow 2: Admin User Management
1. Admin login ke sistem
2. Navigate ke User Management
3. View list users (active/inactive)
4. Create/Edit/Delete user
5. Monitor user activities
6. View prediction history per user

### Flow 3: Admin Model Management
1. Admin login ke sistem
2. Navigate ke Model Management
3. View deployed models
4. Check model status (online/offline)
5. View prediction statistics
6. Deploy new model version (optional)

---

## 🔒 Keamanan

- Authentication menggunakan Laravel Sanctum
- Password hashing dengan bcrypt
- Role-based access control (Admin/User)
- File validation untuk upload
- CORS configuration untuk API
- Auto-delete sensitive data (1 hari)

---

## ⚠️ Catatan Penting

1. **Server Performance**: Sistem menggunakan **Laravel Octane + RoadRunner** untuk performance optimal. Response time ~1-3 detik untuk operation normal, ~17 detik untuk prediction ke Kaggle GPU.

2. **Auto-Delete Warning**: Hasil prediksi akan otomatis dihapus setelah 24 jam. Pastikan download hasil sebelum expired.

3. **File Format**: Hanya file `.tif` 16-bit yang didukung sesuai spesifikasi model.

4. **Interpolasi Rekursif**: Sistem menggunakan metode recursive interpolation pada t=0.5 untuk hasil optimal. Tidak ada input manual time_scalar.

5. **Model Endpoint Management**: 
   - URL Ngrok akan berubah setiap kali restart Colab/Kaggle
   - Update endpoint via **Admin UI → Model Management** (BUKAN via `.env`)
   - Sistem otomatis health check setelah update
   - `NGROK_API_URL` di `.env` sudah deprecated

6. **Storage Management**: Monitor penggunaan storage secara berkala karena file `.tif` berukuran besar.

7. **Authentication**: 
   - Token API berlaku selamanya hingga logout (akan diubah ke 30 hari expiration)
   - User dibuat oleh admin, tidak ada self-registration
   - Reset password by admin, tidak ada "lupa password" flow

---

## 🤝 Kontributor

- **Developer**: Mahasiswa Teknik Informatika - BRIN Internship
- **Supervisor**: Tim Peneliti BRIN
- **Institusi**: Badan Riset dan Inovasi Nasional (BRIN)

---

## 📞 Kontak & Support

- **Email**: admin@brin.go.id
- **Institusi**: BRIN (Badan Riset dan Inovasi Nasional)
- **Documentation**: [Full Documentation](./docs/)

---

## 📄 Lisensi

Project ini dikembangkan untuk keperluan penelitian internal BRIN.

---

## 🎓 Acknowledgments

- BRIN untuk fasilitas penelitian dan komputasi
- Google Colab untuk GPU resources
- TensorFlow/Keras team untuk ML framework
- Flutter & Laravel communities

---

**Last Updated**: August 14, 2026  
**Version**: 1.1.0  
**Status**: Active Development - FASE 2 Complete, FASE 3 Backend Part 1 Complete

## 🎉 Recent Updates (Aug 14, 2026)

### Performance Optimization
- ✅ Migrated to **Laravel Octane + RoadRunner**
- ✅ **84-86% faster** response times
- ✅ Long-running requests (17+ seconds) working without timeout
- ✅ Concurrent handling improved

### Database & Backend
- ✅ 21 API endpoints completed (User, Model, Activity management)
- ✅ Health check command + schedule registered
- ✅ Activity logging for all admin actions
- ✅ Database structure audited & documented
- ✅ Audit fixes: 9 bugs fixed, 30 manual API checks passed

### Frontend
- ✅ Admin dashboard UI complete (home, users, models, activity logs)
- ✅ User management screen with CRUD operations
- ✅ Model management screen with health check
- ✅ Activity logs screen with filters + CSV export

See [TESTING_RESULTS.md](TESTING_RESULTS.md) and [TODO.md](TODO.md) for details.

---

## ⚠️ Status Nyata per 15 Agustus 2026

Diverifikasi langsung terhadap aplikasi yang berjalan, bukan dari catatan lama:

| Hal | Status |
|-----|--------|
| MySQL (Laragon) + `db_aict` | ✅ 13 tabel, 16 migration `Ran` |
| Backend Octane `:8000` | ✅ login admin 200 dalam ~1.5s |
| Tunnel ngrok backend | ✅ hidup (domain reserved, tetap sama antar restart) |
| Endpoint model AI (Kaggle) | ✅ `online` — **mati saat sesi Kaggle putus**, cek ulang dengan `php artisan models:health-check` |
| `flutter analyze` | ✅ 0 issues |
| `flutter test` | ✅ 21 test lulus (layout, status bar, nav, parsing, tile) |
| `flutter build apk --release` | ✅ `app-release.apk` 51 MB |
| `flutter build web --release` | ✅ `build/web` (`--wasm` belum bisa, lihat fe/README) |
| Test otomatis backend | ❌ belum ada — `be/tests/` cuma stub bawaan Laravel |
| Angka "30/30" & "23/23" di dokumen lama | ⚠️ itu checklist `curl` manual, bukan suite |
| Scheduler (`schedule:work`) | ❌ tidak jalan by default — status model jadi basi kalau tidak dijalankan |
| Version control | ✅ git repository aktif di root (branch `main`) |
| FASE 3 (upload/prediksi) | ✅ jalan end-to-end: upload (langsung & berpotong), interpolasi rekursif, download + MD5, retensi 24 jam |
