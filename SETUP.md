# ⚙️ Setup & Installation Guide

Panduan lengkap untuk setup dan menjalankan Platform Analisis Citra Neutron CT.

---

## 📋 Prerequisites

### 1. Backend Requirements (Laravel)
- **PHP**: 8.2 atau lebih tinggi
- **Composer**: Latest version
- **MySQL**: 8.0 atau lebih tinggi
- **Laragon**: Untuk Windows users (recommended)
- **Git**: Untuk version control

### 2. Frontend Requirements (Flutter)
- **Flutter SDK**: 3.0+
- **Dart SDK**: 3.0+
- **Android Studio** atau **VS Code** dengan Flutter extensions
- **Chrome**: Untuk web development

### 3. AI Worker Requirements (Google Colab)
- **Google Account**
- **Ngrok Account**: Untuk public URL
- **Model File**: `generator(Salinan 3 Ginet TC-D_Revisi).h5`

---

## 🚀 Step-by-Step Installation

### STEP 1: Clone Repository

```bash
# Clone project
git clone <repository-url>
cd deepCT-gemini
```

---

### STEP 2: Setup Backend (Laravel)

#### 2.1 Install Dependencies

```bash
cd be
composer install
```

#### 2.2 Environment Configuration

```bash
# Copy example environment file
cp .env.example .env

# Generate application key
php artisan key:generate
```

#### 2.3 Configure Database

Edit file `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=db_aict
DB_USERNAME=root
DB_PASSWORD=

# Octane
OCTANE_SERVER=roadrunner
CACHE_STORE=file
QUEUE_CONNECTION=database
```

> **Jangan tambahkan `NGROK_API_URL`.** Variabel itu peninggalan lama dan
> **tidak dibaca kode manapun**. Endpoint model di-manage lewat tabel `models`
> dan diubah dari Admin UI → Model Management.

#### 2.4 Create Database

**Jika menggunakan Laragon:**
1. Start Laragon
2. Klik "Database" → "Open MySQL console"
3. Jalankan command:

```sql
CREATE DATABASE db_aict;
EXIT;
```

**Atau via command line:**

```bash
mysql -u root -p
CREATE DATABASE db_aict;
EXIT;
```

#### 2.5 Run Migrations & Seeders

```bash
# Run migrations
php artisan migrate

# Seed default data (admin user & model)
php artisan db:seed

# Link storage untuk public access
php artisan storage:link
```

**Default User Credentials:**
- **Admin**: admin@brin.go.id / admin123
- **User**: researcher@brin.go.id / user123

#### 2.6 Start Laravel Server

```bash
php artisan serve
```

Server akan berjalan di: `http://localhost:8000`

**Test API:**
```bash
curl http://localhost:8000/api/health
```

---

### STEP 3: Setup Frontend (Flutter)

#### 3.1 Install Dependencies

```bash
cd fe
flutter pub get
```

#### 3.2 Configure API Endpoint

Edit file `lib/config/api_config.dart` (atau sesuai struktur):

```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:8000/api';
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000;
}
```

#### 3.3 Run Flutter App

**For Web:**
```bash
flutter run -d chrome
```

**For Android Emulator:**
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

**For Android Phone (USB Debugging):**
1. Enable USB Debugging di Android phone
2. Connect via USB
3. Run: `flutter run`

App akan compile dan buka otomatis.

---

### STEP 4: Setup AI Worker (Google Colab)

#### 4.1 Upload Files ke Google Drive

1. Buka Google Drive
2. Buat folder struktur:
```
/content/drive/MyDrive/Model_AI/
├── Data/
│   └── Example/
└── Models/
    └── generator(Salinan 3 Ginet TC-D_Revisi).h5
```

#### 4.2 Open Notebook di Colab

1. Upload `models-ai/Evaluation_2_to_1_1kx1k_With_Logo.ipynb` ke Drive
2. Klik kanan → "Open with Google Colaboratory"

#### 4.3 Mount Google Drive

Run cell:
```python
from google.colab import drive
drive.mount('/content/drive')
```

Authorize access saat diminta.

#### 4.4 Install Dependencies

Run cell:
```python
!pip install fastapi uvicorn pyngrok python-multipart pillow
!pip install tensorflow keras numpy
```

#### 4.5 Load Model

```python
from tensorflow import keras

model_path = '/content/drive/MyDrive/Model_AI/Models/generator(Salinan 3 Ginet TC-D_Revisi).h5'
model = keras.models.load_model(model_path)
print("Model loaded successfully!")
```

#### 4.6 Setup Ngrok

1. Sign up di https://ngrok.com (free tier)
2. Get auth token dari dashboard
3. Run cell:

```python
from pyngrok import ngrok

# Set auth token
ngrok.set_auth_token("YOUR_NGROK_AUTH_TOKEN_HERE")

# Start ngrok tunnel
public_url = ngrok.connect(8000)
print(f"Public URL: {public_url}")
```

#### 4.7 Start FastAPI Server

```python
import uvicorn
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import StreamingResponse

app = FastAPI()

@app.post("/predict")
async def predict(
    file_t0: UploadFile = File(...),
    file_t2: UploadFile = File(...),
    time_scalar: float = 0.5
):
    # Load images
    t0_image = load_image(await file_t0.read())
    t2_image = load_image(await file_t2.read())
    
    # Run prediction
    result = model.predict([t0_image, t2_image, time_scalar])
    
    # Return as binary
    return StreamingResponse(io.BytesIO(result), media_type="image/tiff")

# Start server
uvicorn.run(app, host="0.0.0.0", port=8000)
```

#### 4.8 Copy Ngrok URL

Terminal akan show:
```
Public URL: https://abc123xyz.ngrok-free.dev
```

**Copy URL ini**, lalu update endpoint model lewat **Admin UI → Model Management
→ Edit → Endpoint URL** (bukan lewat `.env` — `NGROK_API_URL` tidak dibaca kode
manapun). Sistem otomatis menjalankan health check setelah endpoint disimpan.

Kalau domain ngrok Anda *reserved*, URL-nya tidak berubah setiap restart dan
tidak perlu diupdate sama sekali.

Verifikasi dari CLI:
```bash
php artisan models:health-check
```

---

## ✅ Verification

### Test Backend API

```bash
# Health check
curl http://localhost:8000/api/health

# Login test
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@brin.go.id","password":"admin123"}'
```

Expected response:
```json
{
  "success": true,
  "data": {
    "user": {...},
    "token": "1|abc123..."
  }
}
```

### Test Frontend

1. Open browser: `http://localhost:xxxx` (port yang ditampilkan saat `flutter run`)
2. Should see Landing Page
3. Click "Login" button
4. Should redirect to login page
5. Login dengan: admin@brin.go.id / admin123
6. Should redirect to Admin Dashboard

### Test AI Worker

```bash
curl -X POST https://your-ngrok-url.ngrok-free.dev/predict \
  -F "file_t0=@/path/to/001.tif" \
  -F "file_t2=@/path/to/003.tif" \
  -F "time_scalar=0.5" \
  --output result.tif
```

File `result.tif` should be downloaded.

---

## 🔧 Troubleshooting

### Backend Issues

#### Error: "Access denied for user 'root'@'localhost'"
**Solution:**
```bash
# Reset MySQL password
mysql -u root
ALTER USER 'root'@'localhost' IDENTIFIED BY '';
FLUSH PRIVILEGES;
EXIT;
```

Update `.env`:
```env
DB_PASSWORD=
```

#### Error: "Class 'XXX' not found"
**Solution:**
```bash
composer dump-autoload
php artisan optimize:clear
```

#### Error: "The stream or file could not be opened"
**Solution:**
```bash
chmod -R 775 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
```

Windows (run as Administrator):
```bash
icacls storage /grant Everyone:F /T
icacls bootstrap\cache /grant Everyone:F /T
```

---

### Frontend Issues

#### Error: "DioException: Connection timeout"
**Solution:**
- Check Laravel server running: `php artisan serve`
- Check API endpoint di `api_config.dart` correct
- Disable antivirus/firewall sementara

#### Error: "flutter: command not found"
**Solution:**
```bash
# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Or install via:
# Windows: https://docs.flutter.dev/get-started/install/windows
# Mac: brew install flutter
```

#### Error: "Waiting for another flutter command to release the startup lock"
**Solution:**
```bash
rm flutter/bin/cache/lockfile
```

---

### AI Worker Issues

#### Error: "CUDA out of memory"
**Solution:**
- Restart Colab runtime
- Use Colab Pro untuk more RAM/GPU
- Process images sequentially instead of batch

#### Error: "Ngrok tunnel expired"
**Solution:**
- Free tier Ngrok expire setelah 8 hours
- Restart tunnel:
```python
ngrok.kill()
public_url = ngrok.connect(8000)
```
- Update Laravel `.env` dengan URL baru

#### Error: "Model file not found"
**Solution:**
```python
# Check file path
import os
model_path = '/content/drive/MyDrive/Model_AI/Models/generator(Salinan 3 Ginet TC-D_Revisi).h5'
print("File exists:", os.path.exists(model_path))

# If False, check Drive mounting:
from google.colab import drive
drive.mount('/content/drive', force_remount=True)
```

---

## 🔄 Development Workflow

### 1. Start Development Session

```bash
# Terminal 1: Backend
cd be
php artisan serve

# Terminal 2: Frontend
cd fe
flutter run -d chrome

# Terminal 3: Queue Worker (future)
cd be
php artisan queue:work
```

### 2. Watch for Changes

**Backend (auto-reload):**
- Install: `composer require --dev laravel/pint`
- Run: `./vendor/bin/pint --watch`

**Frontend (hot reload):**
- Otomatis dengan `flutter run` dalam debug mode
- Press `r` untuk hot reload
- Press `R` untuk hot restart

### 3. Database Reset (jika perlu)

```bash
php artisan migrate:fresh --seed
```

**Warning:** Ini akan DELETE semua data!

---

## 📊 Monitoring & Logs

### Laravel Logs

```bash
# Tail logs real-time
tail -f storage/logs/laravel.log

# Clear logs
echo "" > storage/logs/laravel.log
```

### Queue Jobs Status

```bash
# Failed jobs
php artisan queue:failed

# Retry failed job
php artisan queue:retry <job-id>

# Retry all failed jobs
php artisan queue:retry all
```

### Database Query Logging

Add to `.env`:
```env
DB_LOG_QUERIES=true
```

Queries akan muncul di `storage/logs/laravel.log`

---

## 🚢 Production Deployment

### Backend (Laravel)

```bash
# Optimize for production
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Set environment
APP_ENV=production
APP_DEBUG=false
```

### Frontend (Flutter)

```bash
# Build web
flutter build web --release

# Build Android APK
flutter build apk --release

# Build Android App Bundle (for Play Store)
flutter build appbundle --release
```

---

## 📞 Support

Jika masih mengalami issues, hubungi:
- **Email**: admin@brin.go.id
- **Documentation**: [Full Documentation](./README.md)

---

**Last Updated**: August 13, 2026  
**Version**: 1.0.0
