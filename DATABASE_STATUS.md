# 📊 Database Structure Status

**Created:** 14 Agustus 2026  
**Purpose:** Quick reference untuk status kolom dan tabel database

---

## ✅ Summary

### Tables Status

**13 tables.** Row counts below were read from `db_aict` on 15 Agustus 2026.

| Table | Status | Records | Notes |
|-------|--------|---------|-------|
| `users` | ✅ Active | 2 | `admin` + `researcher` |
| `personal_access_tokens` | ✅ Active | 37 | API tokens (Sanctum) |
| `password_reset_tokens` | ⚠️ Unused | 0 | Admin-only reset |
| `sessions` | ⚠️ Incidental | 18 | Written by the `/` welcome route (`SESSION_DRIVER=database`); not used for API auth |
| `models` | ✅ Active | 1 | AI model registry |
| `analysis_records` | ⏳ Empty | 0 | Awaiting FASE 3 |
| `user_activities` | ✅ Active | 205 | Audit logs |
| `cache` | ✅ Active | 2 | Auto-managed |
| `cache_locks` | ✅ Active | 0 | Auto-managed |
| `jobs` | ✅ Active | 0 | Queue (empty = good) |
| `job_batches` | ✅ Active | 0 | Not used yet |
| `failed_jobs` | ✅ Active | 0 | Empty = good! |
| `migrations` | ✅ Active | 16 | All migrations `Ran` |

---

## 🔍 Unused Columns (Normal)

### Table: `users`

| Column | Status | Reason | Action |
|--------|--------|--------|--------|
| `email_verified_at` | Not Used | Admin creates users | ✅ Keep (future-proof) |
| `remember_token` | Not Used | API token auth | ✅ Keep (standard Laravel) |

### Table: `personal_access_tokens`

| Column | Status | Reason | Action |
|--------|--------|--------|--------|
| `expires_at` | NULL on every row | Sanctum enforces expiry from `config/sanctum.php` (`'expiration' => 10080`), which applies to *all* tokens regardless of this column. Per-token overrides would populate it. | ✅ Working as intended |

### Table: `models`

| Column | Status | Reason | Action |
|--------|--------|--------|--------|
| `max_concurrent_jobs` | Always 1 | GPU limitation | ✅ Keep (future scaling) |
| `file_path` | Always NULL | Remote deployment | ✅ Keep (nullable) |

---

## ⚠️ Unused Tables

### `password_reset_tokens` (Normal - Tidak Digunakan)
- **Reason:** Admin resets password via UI, tidak ada "lupa password" flow
- **Recommendation:** ✅ Keep (future-proof jika ada self-service)

### `sessions` (Normal - Tidak Digunakan)
- **Reason:** API-only app, tidak ada session-based auth
- **Recommendation:** 🗑️ Consider dropping (cleanup)
- **If dropped:** Update `SESSION_DRIVER=array` di `.env`

---

## 🎯 Recommended Actions

### Priority: HIGH 🔴

**1. Aktifkan Token Expiration** ✅ DONE (14 Agustus 2026)

Token API sekarang expire setelah **7 hari**. Security features:
- ✅ Token expiration: 7 days (10080 minutes)
- ✅ Single session per account: Login baru auto revoke token lama
- ✅ Daily cleanup scheduled: `tokens:cleanup` command

**File:** `config/sanctum.php`
```php
'expiration' => 10080, // 7 days
```

**Cleanup Command:** ✅ Created `app/Console/Commands/CleanupExpiredTokens.php`

**Schedule:** ✅ Daily cleanup di `routes/console.php`

---

### Priority: MEDIUM 🟡

**2. Set email_verified_at di Seeder**

Untuk consistency, set `email_verified_at = now()` untuk semua user yang dibuat admin.

**File:** `database/seeders/AdminUserSeeder.php`
```php
'email_verified_at' => now(),  // Already done ✅
```

---

### Priority: LOW 🟢

**3. Drop Sessions Table (Optional)**

Jika yakin tidak akan pakai session-based auth:

**Migration:**
```bash
php artisan make:migration drop_sessions_table
```

```php
public function up() {
    Schema::dropIfExists('sessions');
}
```

**Update `.env`:**
```env
SESSION_DRIVER=array  # or 'file' for dev
```

---

## 📋 Normal Behavior

### Empty Tables (This is GOOD!)

**`jobs`** - Empty = no queue backlog ✅  
**`job_batches`** - Empty = not using batch jobs ✅  
**`failed_jobs`** - Empty = no failures ✅  
**`cache_locks`** - Temporary, auto cleanup ✅

### Always NULL Columns (This is OK!)

**`models.file_path`** - Remote deployment, NULL expected ✅  
**`users.remember_token`** - API auth, tidak digunakan ✅  
**`personal_access_tokens.expires_at`** - Should be set, but NULL for now ⚠️

---

## 🔒 Security Recommendations

1. **✅ DONE:** Password hashing (bcrypt, rounds=12)
2. **✅ DONE:** Role-based access control
3. **✅ DONE:** Rate limiting on login (5/minute)
4. **✅ DONE:** SQL injection protection (Query Builder)
5. **✅ DONE:** Token expiration — 7 days via `config/sanctum.php`
6. **✅ DONE:** `tokens:cleanup` command exists and is scheduled daily —
   but see the caveat below

---

## 📊 Storage Analysis

### Current Usage (Estimated)

| Table | Rows | Avg Size/Row | Total |
|-------|------|--------------|-------|
| users | 3 | ~1 KB | 3 KB |
| personal_access_tokens | 44 | ~500 B | 22 KB |
| models | 1 | ~2 KB | 2 KB |
| user_activities | 175 | ~1.5 KB | 262 KB |
| **TOTAL** | - | - | **~290 KB** |

**Unused columns impact:** < 1 KB (negligible)

---

## 📖 Context

**Application Type:** API-only platform (no web session)  
**User Management:** Admin-only (no self-registration)  
**Authentication:** Token-based (Laravel Sanctum)  
**Model Deployment:** Remote (Kaggle/Colab)  
**Password Reset:** Admin-triggered (no self-service)

---

## 🔗 Related Documentation

- [DATABASE_CLEANUP.md](be/DATABASE_CLEANUP.md) - Detailed analysis
- [API_DOCS.md](API_DOCS.md) - API endpoints
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture

---

---

## ⚠️ Open Caveat: the scheduler is not running

`tokens:cleanup` (daily) and `models:health-check` (every 5 min) are registered
in `routes/console.php`, but **nothing executes the schedule** — Laragon and
Octane do not start one. Consequences:

- 37 stale tokens are still in `personal_access_tokens`, most of them predating
  the single-session change. They are already rejected at auth time (Sanctum
  checks the 7-day config expiry), so this is housekeeping, not a hole.
- `models.status` only changes when someone triggers a health check by hand or
  through the admin UI. A model can read `online` in the database long after its
  tunnel died.

Fix by running `php artisan schedule:work` alongside Octane, or register a
Windows Scheduled Task for `php artisan schedule:run` every minute.

---

**Conclusion:** The schema is **healthy and appropriate** for current
requirements. The one outstanding item is operational, not structural: start a
scheduler process so the two registered commands actually fire.
