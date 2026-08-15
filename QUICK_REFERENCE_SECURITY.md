# 🔒 Quick Reference - Token Security

**Version:** 1.1.1  
**Status:** ✅ ACTIVE

---

## ⚡ Quick Facts

- **Token Lifetime:** 7 days (10080 minutes)
- **Session Policy:** Single session per account
- **Cleanup Schedule:** Daily at 00:00 (midnight)
- **Security Level:** High ✅

---

## 🎯 What This Means for Users

### For Regular Users (Researchers)
- ✅ Login expires after 7 days → need to login again
- ✅ Login from laptop → phone gets logged out automatically
- ✅ More secure - prevents account hijacking
- ⚠️ Can't share account with teammates (by design)

### For Admins
- ✅ Same rules apply (security for everyone)
- ✅ Can reset user passwords if needed
- ✅ Activity logs track all logins
- ✅ Automatic cleanup keeps database clean

---

## 🔧 Commands (For Admins)

### Check Token Configuration
```bash
php artisan tinker --execute="echo config('sanctum.expiration');"
# Expected output: 10080
```

### Check Scheduled Tasks
```bash
php artisan schedule:list
# Look for: tokens:cleanup (runs daily at 00:00)
```

### Manual Token Cleanup
```bash
php artisan tokens:cleanup
# Output: Deleted X expired token(s).
```

### View Current Tokens
```bash
php artisan tinker
>>> \Laravel\Sanctum\PersonalAccessToken::count()
>>> \Laravel\Sanctum\PersonalAccessToken::where('created_at', '<', now()->subDays(7))->count()
```

---

## 🐛 Troubleshooting

### User Can't Login
**Symptom:** "Token expired" or 401 Unauthorized  
**Cause:** Token older than 7 days  
**Solution:** User needs to login again (normal behavior)

### User Logged Out Unexpectedly
**Symptom:** "Suddenly logged out"  
**Cause:** User logged in from another device  
**Solution:** Normal behavior - only 1 session allowed  
**Explanation:** "You were logged out because you logged in from another device"

### Old Tokens Not Cleaned
**Symptom:** Many old tokens in database  
**Solution:** Check schedule is running
```bash
php artisan schedule:list
php artisan tokens:cleanup  # Manual run
```

---

## 🔄 How to Change Settings

### Change Token Lifetime

**File:** `config/sanctum.php`

```php
// 7 days (current)
'expiration' => 10080,

// 14 days (example)
'expiration' => 20160,

// 30 days (example)
'expiration' => 43200,

// Never expire (NOT RECOMMENDED)
'expiration' => null,
```

**After change:**
```bash
php artisan config:clear
npm run octane
```

### Change Cleanup Schedule

**File:** `routes/console.php`

```php
// Daily at midnight (current)
Schedule::command('tokens:cleanup')->daily();

// Every 12 hours
Schedule::command('tokens:cleanup')->twiceDaily();

// Weekly on Sunday
Schedule::command('tokens:cleanup')->weekly();
```

### Disable Single Session (NOT RECOMMENDED)

**File:** `app/Http/Controllers/API/AuthController.php`

```php
// Comment out this line:
// $user->tokens()->delete();
```

⚠️ **Warning:** This reduces security!

---

## 📊 Monitoring Queries

### Count Active Tokens
```sql
SELECT COUNT(*) FROM personal_access_tokens 
WHERE created_at > NOW() - INTERVAL 7 DAY;
```

### Count Expired Tokens
```sql
SELECT COUNT(*) FROM personal_access_tokens 
WHERE created_at < NOW() - INTERVAL 7 DAY;
```

### Tokens Per User
```sql
SELECT u.name, u.email, COUNT(t.id) as token_count
FROM users u
LEFT JOIN personal_access_tokens t ON u.id = t.tokenable_id
GROUP BY u.id
ORDER BY token_count DESC;
```

### Token Age Distribution
```sql
SELECT 
    CASE 
        WHEN created_at > NOW() - INTERVAL 1 DAY THEN '< 1 day'
        WHEN created_at > NOW() - INTERVAL 3 DAY THEN '1-3 days'
        WHEN created_at > NOW() - INTERVAL 7 DAY THEN '3-7 days'
        ELSE '> 7 days'
    END as age,
    COUNT(*) as count
FROM personal_access_tokens
GROUP BY age;
```

---

## 🎓 For Developers

### Token Flow
```
1. User POST /api/login
   ↓
2. Validate credentials
   ↓
3. Delete all user's old tokens ($user->tokens()->delete())
   ↓
4. Create new token (expires in 7 days)
   ↓
5. Return token to frontend
   ↓
6. Frontend stores token
   ↓
7. Frontend includes token in all requests (Bearer token)
   ↓
8. After 7 days → 401 Unauthorized
   ↓
9. Frontend redirects to login
```

### Testing Single Session

**Setup:**
```bash
# Terminal 1: Login User A
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"researcher@brin.go.id","password":"user123"}'
# Save token as TOKEN_A

# Terminal 2: Test Token A
curl http://localhost:8000/api/user \
  -H "Authorization: Bearer TOKEN_A"
# Expected: 200 OK

# Terminal 1: Login User A again (same user, different session)
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"researcher@brin.go.id","password":"user123"}'
# Save token as TOKEN_B

# Terminal 2: Test Token A again
curl http://localhost:8000/api/user \
  -H "Authorization: Bearer TOKEN_A"
# Expected: 401 Unauthorized (token revoked)

# Terminal 2: Test Token B
curl http://localhost:8000/api/user \
  -H "Authorization: Bearer TOKEN_B"
# Expected: 200 OK
```

---

## 📞 Need Help?

**Questions?** Check `SECURITY_UPDATE.md` for detailed documentation  
**Issues?** Check `storage/logs/laravel.log`  
**Changes?** Update `config/sanctum.php` and clear cache

---

## ✅ Checklist

- [x] Token expiration: 7 days ✅
- [x] Single session: Active ✅
- [x] Auto cleanup: Scheduled ✅
- [x] Documentation: Complete ✅
- [x] Production ready: Yes ✅

---

**Status:** ✅ **ALL SYSTEMS OPERATIONAL**

_Last Updated: August 14, 2026_
