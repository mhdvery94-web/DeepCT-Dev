# Database Structure Cleanup Recommendations

**Created:** 14 Agustus 2026  
**Context:** Review kolom dan tabel yang tidak terpakai dalam konteks aplikasi

---

## 📊 Current Database Structure

### Tables Present
1. ✅ `users` - Used
2. ✅ `personal_access_tokens` - Used (Laravel Sanctum)
3. ⚠️ `password_reset_tokens` - **TIDAK DIGUNAKAN**
4. ⚠️ `sessions` - **TIDAK DIGUNAKAN**
5. ✅ `models` - Used
6. ✅ `analysis_records` - Used
7. ✅ `user_activities` - Used
8. ✅ `cache` - Used
9. ✅ `cache_locks` - Used
10. ✅ `jobs` - Used (queue)
11. ✅ `job_batches` - Used (queue)
12. ✅ `failed_jobs` - Used (queue)

---

## 🔍 Analysis: Kolom & Tabel Tidak Terpakai

### 1. Table: `users`

#### ⚠️ Kolom Tidak Terpakai

**A. `email_verified_at`**
- **Status:** TIDAK DIGUNAKAN
- **Alasan:** 
  - User dibuat oleh admin, bukan self-registration
  - Tidak ada email verification flow
  - Tidak ada "kirim ulang verifikasi email"
- **Rekomendasi:** 
  - ✅ **KEEP** - Standard Laravel, tidak mengganggu
  - Seeder bisa set `email_verified_at = now()` untuk semua user
  - Jika nanti ada self-registration, kolom ini siap digunakan

**B. `remember_token`**
- **Status:** TIDAK DIGUNAKAN
- **Alasan:**
  - Aplikasi menggunakan **API token (Sanctum)**, bukan session-based auth
  - Tidak ada "Remember Me" checkbox di login
  - Token disimpan di `personal_access_tokens`, bukan `remember_token`
- **Rekomendasi:**
  - ✅ **KEEP** - Standard Laravel migration, tidak mengganggu
  - Size: 100 bytes per user (kecil)

---

### 2. Table: `password_reset_tokens`

- **Status:** ⚠️ **TIDAK DIGUNAKAN**
- **Alasan:**
  - User tidak bisa request reset password sendiri
  - Admin melakukan reset password via endpoint `/admin/users/{id}/reset-password`
  - Password baru langsung di-set ke default "BrinResearch2026"
  - Tidak ada "lupa password" flow
- **Rekomendasi:**
  - **OPTION A (Recommended):** ✅ **KEEP**
    - Jika nanti ada self-service "lupa password" untuk researcher
    - Laravel standard table, tidak mengganggu
  - **OPTION B:** 🗑️ **DROP**
    - Jika yakin 100% tidak akan ada self-service reset
    - Hapus via migration baru

---

### 3. Table: `sessions`

- **Status:** ⚠️ **TIDAK DIGUNAKAN**
- **Alasan:**
  - Aplikasi full API, tidak ada session-based authentication
  - Frontend Flutter menggunakan **Bearer token** (Sanctum)
  - Kolom `user_id` di table `sessions` tidak pernah terisi
  - Laravel session driver kita set ke `database`, tapi tidak terpakai
- **Rekomendasi:**
  - **OPTION A:** 🗑️ **DROP** (Recommended)
    - Cleanup migration baru
    - Ubah `SESSION_DRIVER=file` di `.env` (atau `array` untuk testing)
  - **OPTION B:** ✅ **KEEP**
    - Jika nanti ada web admin Laravel (blade/livewire)
    - Tapi saat ini tidak ada rencana

---

### 4. Table: `personal_access_tokens`

#### ⚠️ Kolom Tidak Terpakai

**A. `expires_at`**
- **Status:** TIDAK DIGUNAKAN
- **Alasan:**
  - Token tidak punya expiration
  - Token berlaku selamanya hingga logout atau dihapus manual
  - Sanctum config tidak set expiration
- **Rekomendasi:**
  - **OPTION A:** ✅ **KEEP & AKTIFKAN** (DONE)
    - ✅ Expiration 7 hari sudah diaktifkan (best practice security)
    - ✅ Single session per account (login baru = revoke token lama)
    - Updated `config/sanctum.php`:
      ```php
      'expiration' => 10080, // 7 days
      ```
  - **OPTION B:** 🗑️ **DROP COLUMN**
    - Jika memang tidak ingin ada expiration

**Best Practice:** Token API seharusnya expire untuk security!

---

### 5. Table: `models`

#### ⚠️ Kolom Tidak Optimal

**A. `max_concurrent_jobs`**
- **Status:** SELALU 1 (hardcoded)
- **Alasan:**
  - Kaggle/Colab hanya bisa 1 job parallel (GPU limitation)
  - Kolom ini tidak pernah diubah dari nilai default 1
  - Kode tidak pernah cek nilai ini untuk queue management
- **Rekomendasi:**
  - **OPTION A:** ✅ **KEEP** (Recommended)
    - Jika nanti ada multiple Kaggle workers
    - Atau migrasi ke server GPU dedicated yang bisa parallel
  - **OPTION B:** 🗑️ **DROP COLUMN**
    - Hardcode logic ke 1 job per model

**B. `file_path`**
- **Status:** NULLABLE (setelah fix audit)
- **Alasan:**
  - Model di-deploy remote (Kaggle/Colab)
  - File `.h5` tidak ada di server Laravel
  - Kolom ini selalu NULL untuk semua model
- **Rekomendasi:**
  - ✅ **KEEP NULLABLE**
    - Jika nanti ada local model deployment
    - Dokumentasi jelas: hanya terisi untuk local deployment

---

### 6. Empty Tables (Normal)

Tables berikut **kosong tapi NORMAL**:

#### A. `jobs` (Queue Jobs)
- **Status:** ✅ NORMAL
- **Alasan:** Jobs langsung diproses, tidak antri
- **Note:** Akan terisi jika ada banyak concurrent requests

#### B. `job_batches`
- **Status:** ✅ NORMAL
- **Alasan:** Tidak pakai batch jobs
- **Note:** Laravel feature untuk batch processing

#### C. `failed_jobs`
- **Status:** ✅ NORMAL (bagus jika kosong!)
- **Alasan:** Tidak ada job yang gagal
- **Note:** Akan terisi otomatis jika ada exception di `ProcessDeepLearningImage`

#### D. `cache_locks`
- **Status:** ✅ NORMAL
- **Alasan:** Cache locks temporary, auto cleanup
- **Note:** Terisi saat ada concurrent cache access

---

## 📋 Summary Recommendations

### ✅ KEEP (Tidak Perlu Action)

| Item | Alasan |
|------|--------|
| `users.email_verified_at` | Standard Laravel, future-proof |
| `users.remember_token` | Standard Laravel, kecil |
| `password_reset_tokens` table | Future-proof untuk self-service |
| `models.max_concurrent_jobs` | Future scaling |
| `models.file_path` | Future local deployment |
| Empty queue tables | Normal behavior |

### ⚠️ CONSIDER CLEANUP

| Item | Priority | Action |
|------|----------|--------|
| `sessions` table | Medium | DROP - tidak terpakai di API app |
| `personal_access_tokens.expires_at` | **HIGH** | **AKTIFKAN** - security best practice! |

---

## 🔧 Recommended Actions

### 1. Aktifkan Token Expiration (PRIORITY!)

**File:** `config/sanctum.php`
```php
'expiration' => 10080, // 7 days (7 * 24 * 60 minutes)
```

**✅ UPDATE (14 Agustus 2026):** Token expiration sudah diaktifkan dengan 7 hari + single session per account.

**Migration untuk cleanup token expired:**
```bash
php artisan make:command CleanupExpiredTokens
```

### 2. Cleanup Sessions Table (Optional)

**Migration:**
```php
php artisan make:migration drop_sessions_table
```

```php
public function up()
{
    Schema::dropIfExists('sessions');
}
```

**Update `.env`:**
```env
SESSION_DRIVER=array  # atau 'file' untuk development
```

### 3. Documentation Updates

Update `API_DOCS.md` dan `ARCHITECTURE.md` untuk klarifikasi:
- Token expiration policy
- Session vs Token authentication
- Queue behavior

---

## 📊 Database Size Impact

### Current Unused Space

| Table/Column | Size Impact | Annual Growth |
|--------------|-------------|---------------|
| `sessions` | ~0 MB (empty) | 0 (tidak terpakai) |
| `password_reset_tokens` | ~0 MB (empty) | 0 (tidak terpakai) |
| `users.remember_token` | ~0.1 KB/user | Negligible |
| `users.email_verified_at` | ~8 bytes/user | Negligible |

**Total:** < 1 MB untuk 1000 users

**Conclusion:** Tidak ada pressure untuk cleanup dari sisi storage.

---

## 🎯 Final Recommendation

### DO NOW (Critical):
1. ✅ **Aktifkan token expiration** di Sanctum config (security!)
2. ✅ **Buat command cleanup expired tokens**
3. ✅ **Update dokumentasi** tentang authentication flow

### CONSIDER (Nice to have):
1. ⏳ Drop `sessions` table (cleanup, tapi tidak urgent)
2. ⏳ Set `email_verified_at` di seeder (consistency)

### KEEP AS IS:
1. ✅ `password_reset_tokens` - future-proof
2. ✅ `remember_token` - standard Laravel
3. ✅ `max_concurrent_jobs` - future scaling
4. ✅ `file_path` - future local model

---

## 📝 Notes

**Prinsip Design:**
- ✅ **Future-proof:** Keep kolom yang mungkin digunakan nanti
- ✅ **Security:** Aktifkan expiration untuk API tokens
- ✅ **Simplicity:** Drop yang benar-benar tidak akan digunakan
- ✅ **Laravel Standards:** Keep standard migrations kecuali ada alasan kuat

**Context Aplikasi:**
- **Admin-only user management** - tidak ada self-registration
- **API-first architecture** - tidak ada session
- **Remote model deployment** - tidak ada local file storage
- **Single GPU limitation** - max_concurrent_jobs = 1

---

**Status:** Documented for future reference  
**Decision Required:** Token expiration policy
