# Bagian B1 — Pembersihan skema: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengganti `users.username` dengan `users.phone` (opsional, tidak unik), menghapus `models.max_concurrent_jobs` yang tidak pernah dipakai, dan membuat lencana status membaca label ramah alih-alih nama status mentah.

**Architecture:** Rename lebar dikerjakan dengan *expand-migrate-contract*, bukan sekali tebas: kolom baru ditambahkan dan yang lama dilonggarkan lebih dulu, penulis dipindahkan, pembaca dipindahkan, klien dipindahkan, baru kolom lama dijatuhkan. Setiap task berakhir dengan suite hijau, sehingga kegagalan di tengah selalu menunjuk ke satu langkah.

**Tech Stack:** Laravel 12 + Octane/RoadRunner, Flutter, MySQL.

## Global Constraints

- **`phone` adalah `string(30)`, nullable, TIDAK unik.** Ketiganya wajib. Menambahkan `unique` di kemudian hari membatalkan seluruh maksud perubahan ini.
- **Tidak ada validasi format nomor telepon.** Nomor Indonesia ditulis dengan `+62`, `62`, dan `0`; menolak salah satunya hanya membuat admin bertengkar dengan formulir.
- **Bahasa antarmuka Inggris**, termasuk pesan kegagalan. Balasan ke pengguna dalam percakapan tetap Indonesia.
- **Sudut kotak** (`BorderRadius.zero`), `withValues(alpha:)` bukan `withOpacity`.
- **Jangan tambah dokumen status.** Hasil ke `CHANGELOG.md`, centang di `ROADMAP.md` §12 hanya setelah diverifikasi.
- **Tidak ada paket Flutter baru di B1.** `pubspec.yaml` tidak disentuh.
- **Octane tidak bisa restart sendiri di Windows** — `npm run octane:reset` setelah mengubah PHP. `route:list` bukan bukti.
- **Test backend butuh `db_aict_test`.** `$this->apiAs($token)`, bukan `withHeader('Authorization', …)`.
- **Dasar sebelum B1:** backend 250 test, Flutter 144 test, `flutter analyze` bersih.
- **Menyunting berkas test bersifat mekanis.** Buang kunci `username`; jangan sentuh apa pun yang lain di baris yang sama. Melemahkan asersi sambil "merapikan" adalah kegagalan diam-diam.

---

### Task 1: Tambahkan `phone`, longgarkan `username`

Langkah *expand*. Tidak ada yang rusak: kolom baru muncul, kolom lama masih ada tapi berhenti memaksa.

**Files:**
- Create: `be/database/migrations/2026_08_22_100001_add_phone_to_users_table.php`
- Modify: `be/app/Models/User.php` (`$fillable`, `toPublicArray()`)
- Test: `be/tests/Feature/UserPhoneTest.php` (baru)

**Interfaces:**
- Produces: kolom `users.phone` (`string(30)`, nullable, tanpa unique); `users.username` menjadi nullable dan kehilangan indeks uniknya; `User::toPublicArray()` mengembalikan **keduanya**, `username` dan `phone`.

- [ ] **Step 1: Tulis migrasinya**

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Step one of replacing `username` with `phone`.
 *
 * Deliberately additive. Dropping `username` here would break every test file
 * that creates a user — thirteen of them — in the same commit that adds the
 * column meant to replace it, leaving no point in the middle where the suite
 * is green and a failure means one thing.
 *
 * So: `phone` appears, `username` stops being required and stops being
 * unique, and everything keeps working. Writers move next, then readers, then
 * the client. `username` is dropped last, once nothing names it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // 30 characters covers an international number with spaces and
            // hyphens. No format validation: Indonesian numbers are written
            // +62, 62 and 0 interchangeably, and rejecting any of those only
            // starts an argument with the form.
            $table->string('phone', 30)->nullable()->after('email');
        });

        // Separate statement: MySQL will not drop a unique index in the same
        // breath as altering the column it covers.
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['username']);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable()->change();
        });
    }

    public function down(): void
    {
        // Anything created after this migration may have a null username, and
        // several may share one. Both have to be resolved before the old
        // constraints can go back on.
        DB::table('users')->whereNull('username')->update([
            'username' => DB::raw("CONCAT('user', id)"),
        ]);

        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable(false)->change();
            $table->unique('username');
            $table->dropColumn('phone');
        });
    }
};
```

Tambahkan `use Illuminate\Support\Facades\DB;` di bagian atas berkas, di samping import yang lain.

- [ ] **Step 2: Jalankan migrasinya**

Run: `cd be && php artisan migrate`
Expected: `2026_08_22_100001_add_phone_to_users_table ... DONE`

Bila gagal dengan `doctrine/dbal` tidak ditemukan, Laravel 12 tidak membutuhkannya — `->change()` sudah didukung inti. Bila gagal karena nama indeks, jalankan `SHOW INDEX FROM users;` dan pakai nama sebenarnya di `dropUnique`.

- [ ] **Step 3: Tulis test yang gagal**

Berkas baru `be/tests/Feature/UserPhoneTest.php`:

```php
<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * What `phone` is, stated as tests so it cannot quietly become something else.
 *
 * `username` was NOT NULL and unique, so every account creation had to invent
 * one. `phone` answers the question that actually comes up — how do I reach
 * this researcher — and gets out of the way when nobody knows the answer yet.
 */
class UserPhoneTest extends TestCase
{
    use RefreshDatabase;

    private function user(array $overrides = []): User
    {
        return User::create(array_merge([
            'name' => 'Researcher',
            'email' => 'r' . uniqid() . '@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'is_active' => true,
        ], $overrides));
    }

    public function test_an_account_can_exist_without_a_phone_number(): void
    {
        $user = $this->user();

        $this->assertNull($user->fresh()->phone);
    }

    /**
     * The whole point of the change. A shared office line, or two researchers
     * on one handset, must not stop the second account being created — which
     * is exactly what `username` being unique did.
     */
    public function test_two_accounts_may_share_one_phone_number(): void
    {
        $this->user(['phone' => '+62 812 3456 7890']);
        $second = $this->user(['phone' => '+62 812 3456 7890']);

        $this->assertSame('+62 812 3456 7890', $second->fresh()->phone);
        $this->assertSame(2, User::where('phone', '+62 812 3456 7890')->count());
    }

    public function test_a_phone_number_travels_with_the_user_payload(): void
    {
        $user = $this->user(['phone' => '08123456789']);

        $this->assertArrayHasKey('phone', $user->toPublicArray());
        $this->assertSame('08123456789', $user->toPublicArray()['phone']);
    }
}
```

- [ ] **Step 4: Jalankan test, pastikan gagal**

Run: `cd be && php artisan test --filter=UserPhoneTest`
Expected: FAIL. `test_an_account_can_exist_without_a_phone_number` lolos secara kebetulan, dua lainnya gagal — `phone` belum ada di `$fillable`, jadi nilainya dibuang diam-diam, dan `toPublicArray()` belum menyebutnya.

- [ ] **Step 5: Tambahkan `phone` ke model**

Di `be/app/Models/User.php`, dalam array `$fillable`, tepat setelah `'username',`:

```php
        'username',
        'phone',
```

Dan di `toPublicArray()`, tepat setelah baris `'username' => $this->username,`:

```php
            'username' => $this->username,
            'phone' => $this->phone,
```

Keduanya ada berdampingan untuk sementara. `username` pergi di Task 5, setelah klien berhenti membacanya.

- [ ] **Step 6: Jalankan test, pastikan lulus**

Run: `cd be && php artisan test --filter=UserPhoneTest`
Expected: PASS, 3 test.

- [ ] **Step 7: Seluruh test backend**

Run: `cd be && php artisan test`
Expected: PASS, 253 test. Tidak ada yang rusak — migrasi ini hanya menambah dan melonggarkan.

- [ ] **Step 8: Commit**

```bash
git add be/database/migrations/2026_08_22_100001_add_phone_to_users_table.php be/app/Models/User.php be/tests/Feature/UserPhoneTest.php
git commit -m "Add a phone number beside username, and stop username being required"
```

---

### Task 2: Backend berhenti **menulis** `username`

**Files:**
- Modify: `be/app/Http/Controllers/API/UserController.php` — baris 32-40, 74, 93, 108, 147, 159-160, 166, 172, 198, 205, 210, 242, 278
- Modify: `be/app/Http/Controllers/API/AccessRequestController.php` — baris 162, 191, 205, 270-278
- Modify: `be/app/Models/AccessRequest.php` — baris 64-70
- Test: `be/tests/Feature/UserPhoneTest.php` (ditambah)

**Interfaces:**
- Consumes: kolom `users.phone` dari Task 1.
- Produces: `POST /admin/users` dan `PUT /admin/users/{id}` menerima `phone` (`nullable|string|max:30`) dan **tidak lagi** menerima `username`. Pencarian pengguna mencocokkan `name`, `email`, `phone`. `AccessRequest::suggestedUsername()` dan `AccessRequestController::uniqueUsername()` **tidak ada lagi**.

- [ ] **Step 1: Tulis test yang gagal**

Tambahkan ke `be/tests/Feature/UserPhoneTest.php`, sebelum kurung tutup kelas:

```php
    private function admin(): User
    {
        return $this->user([
            'name' => 'Admin',
            'email' => 'admin@brin.go.id',
            'role' => 'admin',
        ]);
    }

    public function test_an_administrator_can_create_an_account_with_a_phone(): void
    {
        $admin = $this->admin();
        $token = $this->tokenFor($admin->email, 'password123');

        $this->apiAs($token)->postJson('/api/admin/users', [
            'name' => 'New Researcher',
            'email' => 'new@brin.go.id',
            'phone' => '0812 3456 7890',
            'role' => 'user',
        ])->assertCreated();

        $this->assertSame(
            '0812 3456 7890',
            User::where('email', 'new@brin.go.id')->first()->phone
        );
    }

    public function test_an_administrator_can_create_an_account_without_a_phone(): void
    {
        $admin = $this->admin();
        $token = $this->tokenFor($admin->email, 'password123');

        $this->apiAs($token)->postJson('/api/admin/users', [
            'name' => 'No Phone',
            'email' => 'nophone@brin.go.id',
            'role' => 'user',
        ])->assertCreated();

        $this->assertNull(User::where('email', 'nophone@brin.go.id')->first()->phone);
    }

    public function test_users_can_be_searched_by_phone_number(): void
    {
        $admin = $this->admin();
        $this->user(['name' => 'Findable', 'phone' => '081299998888']);
        $this->user(['name' => 'Unrelated', 'phone' => '081200001111']);

        $token = $this->tokenFor($admin->email, 'password123');

        $this->apiAs($token)->getJson('/api/admin/users?search=99998888')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Findable');
    }

    /**
     * Approving a request used to call `uniqueUsername(suggestedUsername())`,
     * two methods whose only job was inventing a value for a column nobody
     * read. Both are gone; this asserts the path still works without them.
     */
    public function test_approving_an_access_request_creates_an_account(): void
    {
        $admin = $this->admin();
        $token = $this->tokenFor($admin->email, 'password123');

        $request = \App\Models\AccessRequest::create([
            'first_name' => 'Ayu',
            'last_name' => 'Pratiwi',
            'email' => 'ayu@brin.go.id',
            'institution' => 'BRIN',
            'reason' => 'Neutron CT research',
            'status' => 'pending',
        ]);

        $this->apiAs($token)
            ->postJson("/api/admin/access-requests/{$request->id}/approve", [])
            ->assertOk();

        $created = User::where('email', 'ayu@brin.go.id')->first();
        $this->assertNotNull($created);
        $this->assertNull($created->phone);
    }
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd be && php artisan test --filter=UserPhoneTest`
Expected: FAIL. Ketiga test pembuatan/pencarian gagal dengan 422 `The username field is required.`; test persetujuan lulus untuk sekarang karena `uniqueUsername` masih ada.

- [ ] **Step 3: Perbaiki pencarian di `UserController`**

Ganti blok pencarian di `be/app/Http/Controllers/API/UserController.php:32-40`:

```php
        $query = User::query();

        // Name, email or phone. `username` used to lead this list; it was the
        // column an administrator was least likely to remember and the one
        // nobody chose for themselves.
        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('phone', 'like', "%{$search}%");
            });
        }
```

- [ ] **Step 4: Perbaiki pembuatan akun**

Di `be/app/Http/Controllers/API/UserController.php`, dalam `store()`, ganti baris validasi `'username' => ...`:

```php
            'phone' => 'nullable|string|max:30',
```

dan dalam `User::create([...])`, ganti `'username' => $request->username,`:

```php
            'phone' => $request->input('phone'),
```

- [ ] **Step 5: Perbaiki pembaruan akun**

Di `update()`, ganti baris validasi `'username' => ['sometimes', ...]`:

```php
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
```

lalu di tiga tempat yang menyebut daftar field, ganti `'username'` menjadi `'phone'`:

```php
        $oldData = $user->only(['name', 'phone', 'email', 'role']);
        $user->update($request->only(['name', 'phone', 'email', 'role']));
```

dan dalam blok metadata log:

```php
                'new_data' => $user->only(['name', 'phone', 'email', 'role']),
```

`Rule::unique` tidak lagi dipakai di baris ini. Bila `use Illuminate\Validation\Rule;` jadi tidak terpakai sama sekali di berkas ini, buang import-nya; periksa dulu — `Rule::in` masih dipakai untuk `role`.

- [ ] **Step 6: Deskripsi log memakai nama**

Di `be/app/Http/Controllers/API/UserController.php`, tujuh baris menyebut `{$user->username}` di dalam `description`. Ganti semuanya menjadi `{$user->name}`:

- baris 108 — `"Created new user: {$user->name}"`
- baris 166 — `"Updated user: {$user->name}"`
- baris 242 — `"Changed user {$user->name} status to " . (...)`
- baris 278 — `"Reset password for user: {$user->name}"`

Untuk penghapusan, baris 198 dan 205-210:

```php
        $name = $user->name;
        ...
            'description' => "Deleted user: {$name}",
            ...
                'name' => $name,
```

Kunci metadata `'username' => $username` menjadi `'name' => $name`. Baris `user_activities` yang **sudah tertulis** tidak disentuh: itu catatan tentang apa yang benar saat kejadian, dan menulisnya ulang agar cocok dengan skema hari ini akan jadi kebohongan yang lebih buruk daripada kolom yang sudah tidak ada.

- [ ] **Step 7: Cabut pengarang username**

Di `be/app/Http/Controllers/API/AccessRequestController.php:162`, buang seluruh baris `'username' => $this->uniqueUsername(...)` dari array `User::create([...])`.

Baris 191 dan 205 memasukkan `'username' => $user->username` ke dalam metadata log dan payload respons. Ganti keduanya menjadi `'name' => $user->name` bila kunci `name` belum ada di sana; bila sudah ada, buang baris `username` saja.

Hapus seluruh metode `uniqueUsername()` beserta komentarnya, baris 269-278.

Di `be/app/Models/AccessRequest.php`, hapus seluruh metode `suggestedUsername()`, baris 63-70.

- [ ] **Step 8: Jalankan test, pastikan lulus**

Run: `cd be && php artisan test --filter=UserPhoneTest`
Expected: PASS, 7 test.

- [ ] **Step 9: Seluruh test backend**

Run: `cd be && php artisan test`
Expected: **GAGAL sebagian.** `AccessRequestTest` menegaskan username yang diarang; test itu disunting di Task 4. Catat berapa yang gagal dan berkas mana — angkanya dipakai di Task 4.

Bila ada yang gagal **selain** karena `username`, berhenti dan periksa: itu bukan bagian dari rencana ini.

- [ ] **Step 10: Commit**

```bash
git add be/app/Http/Controllers/API/UserController.php be/app/Http/Controllers/API/AccessRequestController.php be/app/Models/AccessRequest.php be/tests/Feature/UserPhoneTest.php
git commit -m "Take a phone number where an invented username used to go"
```

Commit ini meninggalkan suite merah di berkas test yang masih menyebut `username`. Task 4 menutupnya. Bila itu mengganggu, kerjakan Task 2, 3 dan 4 sebelum commit pertama.

---

### Task 3: Backend berhenti **membaca** `username`

**Files:**
- Modify: `be/app/Models/Conversation.php:65`
- Modify: `be/app/Http/Controllers/API/MessageController.php:37,63,104,105,247,268,301,302`
- Modify: `be/app/Http/Controllers/API/NewsController.php:41,108,168`
- Modify: `be/app/Http/Controllers/API/TrainingController.php:32,131,165,391,433`
- Modify: `be/app/Http/Controllers/API/UserActivityController.php:22,67`
- Modify: `be/app/Http/Controllers/API/AccessRequestController.php:91,92`

**Interfaces:**
- Consumes: `users.phone` dari Task 1.
- Produces: tidak ada kueri `with()` yang memuat `username`; tidak ada fallback `?? $user->username`.

- [ ] **Step 1: Buang `username` dari daftar `with()`**

Sebelas tempat memuat kolom secara eksplisit dalam string relasi. Di setiap baris berikut, buang `username,` dari daftar — sisanya tidak berubah:

| Berkas | Baris | Menjadi |
|---|---|---|
| `MessageController.php` | 104, 247, 301 | `'user:id,name,email,avatar_path'` |
| `MessageController.php` | 105, 302 | `'messages.author:id,name,avatar_path'` |
| `NewsController.php` | 108, 168 | `'author:id,name'` |
| `TrainingController.php` | 32 | `'uploader:id,name'` |
| `TrainingController.php` | 131, 165 | `'creator:id,name'` |
| `UserActivityController.php` | 22, 67 | `'user:id,name,email,avatar_path'` |
| `AccessRequestController.php` | 91 | `'reviewer:id,name'` |
| `AccessRequestController.php` | 92 | `'createdUser:id,email'` |

- [ ] **Step 2: Hapus empat fallback yang sudah mati**

`users.name` **tidak nullable**, jadi `$user->name ?? $user->username` tidak pernah menjalankan cabang keduanya — sekali pun. Menggantinya dengan `?? $user->phone` hanya memindahkan kesalahpahaman, jadi cabangnya dihapus.

`be/app/Http/Controllers/API/MessageController.php:37` — hapus baris `?? $message->author?->username`, sisakan rantai tanpa baris itu.

`be/app/Http/Controllers/API/NewsController.php:41`:

```php
                ? $post->author->name
```

`be/app/Http/Controllers/API/TrainingController.php:391`:

```php
                ? $dataset->uploader->name
```

`be/app/Http/Controllers/API/TrainingController.php:433`:

```php
                ? $job->creator->name
```

- [ ] **Step 3: `Conversation` tetap punya fallback, dengan alasan berbeda**

`be/app/Models/Conversation.php:65` bukan kasus yang sama. Di sini `$this->user` **sendiri** bisa null — percakapan tamu tidak punya akun sama sekali — jadi fallback terakhirnya nyata dan tetap tinggal:

```php
        return $this->user?->name ?? "User #{$this->user_id}";
```

- [ ] **Step 4: Pencarian kotak masuk admin**

`be/app/Http/Controllers/API/MessageController.php:268` mencari percakapan lewat username. Ganti menjadi `phone`:

```php
                        ->orWhere('phone', 'like', "%{$search}%")
```

- [ ] **Step 5: Payload percakapan**

`be/app/Http/Controllers/API/MessageController.php:63` mengirim `'username' => $conversation->user->username`. Buang baris itu; `name` sudah ada di sebelahnya.

- [ ] **Step 6: Seluruh test backend**

Run: `cd be && php artisan test`
Expected: masih gagal di berkas test yang menyebut `username`, tapi **jumlah kegagalannya tidak boleh bertambah** dibanding Task 2 Step 9. Bila bertambah, sebuah pembaca terlewat.

- [ ] **Step 7: Commit**

```bash
git add be/app/Models/Conversation.php be/app/Http/Controllers/API/MessageController.php be/app/Http/Controllers/API/NewsController.php be/app/Http/Controllers/API/TrainingController.php be/app/Http/Controllers/API/UserActivityController.php be/app/Http/Controllers/API/AccessRequestController.php
git commit -m "Stop loading and reading a column nothing writes any more"
```

---

### Task 4: Berkas test berhenti menyebut `username`

Murni mekanis. Tiga belas berkas, 38 penyebutan.

**Files:**
- Modify: `be/tests/Feature/AccessRequestTest.php` (8), `AuthorizationTest.php` (3), `AuthTest.php` (2), `AvatarTest.php` (3), `ChunkedUploadTest.php` (2), `MessagingTest.php` (3), `ModelAvailabilityTest.php` (1), `NewsPostTest.php` (3), `NotificationTest.php` (3), `PredictionCleanupTest.php` (1), `PredictionPipelineTest.php` (3), `ResearcherTrainingTest.php` (3), `TrainingTest.php` (3)

**Interfaces:**
- Consumes: skema dari Task 1.
- Produces: tidak ada berkas test yang menyebut `username`.

- [ ] **Step 1: Temukan setiap penyebutan**

Run: `cd be && grep -rn "username" tests/`

Kerjakan berkas demi berkas. Tiga bentuk yang akan Anda temui:

1. **Kunci dalam pembuatan user** — `'username' => 'researcher',` di dalam `User::create([...])`. **Buang barisnya.**
2. **Parameter pembantu** — `private function makeUser(string $username, string $email, string $role)`. Ganti nama parameternya jadi `$name` dan pakai untuk `'name' => ucfirst($name)`; buang kunci `username`. `AuthorizationTest.php:40-48` berbentuk begini.
3. **Asersi tentang username** — `AccessRequestTest.php` menegaskan username yang diarang saat persetujuan. **Hapus asersi itu**, jangan diganti dengan asersi tentang `phone`: persetujuan tidak menerima nomor telepon dari mana pun, jadi asersi penggantinya akan menguji `null` dan tidak mengatakan apa-apa. Cakupan yang hilang sudah diambil alih `test_approving_an_access_request_creates_an_account` di Task 2.

**Aturannya: buang kunci `username`, jangan sentuh apa pun yang lain di baris yang sama.** Melemahkan sebuah asersi sambil "merapikan" adalah cara paling mudah membuat suite hijau yang tidak menguji apa pun.

- [ ] **Step 2: Pastikan bersih**

Run: `cd be && grep -rn "username" tests/ ; echo "keluar: $?"`
Expected: tidak ada keluaran, `keluar: 1`.

- [ ] **Step 3: Seluruh test backend**

Run: `cd be && php artisan test`
Expected: PASS. Jumlahnya 257 — 250 dasar, ditambah 7 dari `UserPhoneTest`, dikurangi asersi username yang dihapus dari `AccessRequestTest` (asersi berkurang, jumlah test tidak). Bila jumlah **test** berkurang, sebuah test terhapus dan bukan sekadar asersinya — kembalikan.

- [ ] **Step 4: Commit**

```bash
git add be/tests/
git commit -m "Stop tests inventing a username for every account they create"
```

---

### Task 5: Flutter beralih ke `phone`

**Files:**
- Modify: `fe/lib/models/user_model.dart:3,23,37,56,85`
- Modify: `fe/lib/services/admin_user_service.dart:51,60,79,83,89`
- Modify: `fe/lib/screens/admin/user_management_screen.dart` — 14 tempat
- Modify: `fe/lib/models/access_request.dart:59,62`
- Modify: `fe/lib/services/access_request_service.dart:9,15,108`
- Modify: `fe/lib/screens/admin/access_requests_screen.dart:203`
- Modify: `fe/lib/models/activity_log.dart:3,17,34,71,80`
- Modify: `fe/lib/screens/admin/activity_logs_screen.dart:267`
- Modify: `fe/lib/screens/admin/admin_shell.dart:265`
- Modify: `fe/lib/screens/user/user_shell.dart:256`
- Modify: `fe/lib/widgets/user_avatar.dart:133`
- Test: `fe/test/avatar_test.dart:11,24,39,56`, `fe/test/password_gate_test.dart:29`

**Interfaces:**
- Consumes: `phone` dalam payload user dari Task 1.
- Produces: `UserModel.phone` bertipe `String?`; `AdminUserService.create()` dan `update()` menerima `String? phone`; `ActivityLog.userUsername` **tidak ada lagi**; `ApprovedAccount.username` **tidak ada lagi**.

- [ ] **Step 1: `UserModel`**

Di `fe/lib/models/user_model.dart`, ganti `final String username;` menjadi:

```dart
  /// Optional and not unique — how to reach this researcher, not how to
  /// identify them. Nullable because most accounts will not have one.
  final String? phone;
```

Di konstruktor, `required this.username,` menjadi `this.phone,` — **bukan** `required`, karena ia boleh kosong.

Di `fromJson`, `username: json['username'],` menjadi:

```dart
      phone: json['phone']?.toString(),
```

`json['username']` dibaca tanpa `?.toString()` dan akan melempar bila null; `phone` harus menahannya.

Di `toJson`, `'username': username,` menjadi `'phone': phone,`. Di `copyWith` (baris 85), `username: username,` menjadi `phone: phone,` — dan tambahkan parameternya di tanda tangan `copyWith` bila di sana ada satu per field.

- [ ] **Step 2: `AdminUserService`**

Di `fe/lib/services/admin_user_service.dart`, pada `create()` dan `update()`, ganti `required String username,` menjadi `String? phone,`, dan kunci payload `'username': username` menjadi `'phone': phone`.

Perbarui komentar dokumentasi baris 79:

```dart
  /// PUT /admin/users/{id} — only name, phone, email and role are editable.
```

- [ ] **Step 3: `UserManagementScreen`**

Empat belas tempat. Tujuh di antaranya menyusun kalimat untuk pengguna dan memakai `user.username`; semuanya jadi `user.name` — sebuah nama adalah yang orang kenali:

- baris 130-131 — `'${user.name} has been deactivated'` / `activated`
- baris 159 — `'Reset the password for "${user.name}" to the platform default?'`
- baris 177 — `Text('New password for ${user.name}:')`
- baris 209 — `'Permanently delete "${user.name}"? This cannot be undone.'`
- baris 217 — `_showMessage('${user.name} deleted')`

Baris 301, teks petunjuk pencarian:

```dart
              hintText: 'Search name, email, phone',
```

Baris 409 menampilkan `user.username` sebagai kolom tabel. Ganti menjadi:

```dart
                                  user.phone ?? '—',
```

Em dash, bukan string kosong: sel kosong terbaca seperti kegagalan memuat.

Baris 573, 588, 597, 616, 625, 705 adalah pengendali formulir. Ganti nama `_username` menjadi `_phone` di keenamnya, dan:

```dart
    _phone = TextEditingController(text: u?.phone ?? '');
```

Pada dua pemanggilan layanan (baris 616, 625):

```dart
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
```

String kosong dikirim sebagai `null`, bukan `''` — kolom yang tidak diisi berarti tidak ada nomor, bukan nomor kosong.

Pada `TextFormField` baris 705, ganti `controller: _username` menjadi `controller: _phone`, labelnya menjadi `'Phone'`, dan **buang validator apa pun yang menuntut isian** — kolom ini opsional. Tambahkan `keyboardType: TextInputType.phone`.

- [ ] **Step 4: Permintaan akses**

Di `fe/lib/services/access_request_service.dart`, hapus field `final String username;` (baris 9), parameternya (baris 15), dan pembacaannya (baris 108).

Di `fe/lib/screens/admin/access_requests_screen.dart:203`, hapus seluruh baris `_CredentialRow(label: 'Username', value: account.username),`.

Di `fe/lib/models/access_request.dart:59`, fallback nama peninjau:

```dart
          ? reviewer['name']?.toString()
```

Baris 62 membaca `createdUser['username']`. Karena `createdUser` kini dimuat sebagai `id,email` saja, ganti menjadi:

```dart
          ? createdUser['email']?.toString()
```

- [ ] **Step 5: Log aktivitas**

Di `fe/lib/models/activity_log.dart`, hapus `final String? userUsername;` (baris 17), parameternya (baris 34), dan pembacaannya (baris 71). Perbarui komentar baris 3-4 supaya tidak lagi menyebut `username` dalam daftar kolom yang dimuat.

`actorLabel` (baris 79-84) menjadi:

```dart
  /// Best available label for the actor; deleted users fall back to their ID.
  String get actorLabel {
    if (userName != null && userName!.isNotEmpty) return userName!;
    if (userId != null) return 'User #$userId';
    return 'System';
  }
```

Di `fe/lib/screens/admin/activity_logs_screen.dart:267`:

```dart
                child: Text(u.name, overflow: TextOverflow.ellipsis),
```

- [ ] **Step 6: Sidebar dan avatar**

`fe/lib/screens/admin/admin_shell.dart:265` — `user?.name ?? 'admin'`.
`fe/lib/screens/user/user_shell.dart:256` — `user?.name ?? 'researcher'`.
`fe/lib/widgets/user_avatar.dart:133` — `name: user?.name ?? '?',`.

- [ ] **Step 7: Test Flutter**

`fe/test/avatar_test.dart` baris 11, 24, 39 memasang `username: 'dyanna'` / `'username': 'dyanna'`. Buang ketiganya. Baris 56, `expect(updated.username, 'dyanna')`, menjadi:

```dart
      expect(updated.name, 'Dyanna Basia');
```

`'Dyanna Basia'` adalah nilai `name` yang sudah dipakai berkas itu di baris 12 dan 26 — bukan nilai baru.

`fe/test/password_gate_test.dart:29` — buang baris `username: 'researcher',`.

- [ ] **Step 8: Analisa dan test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 144 test lulus. Jumlahnya tidak berubah — Task ini menyunting test yang ada, tidak menambah.

- [ ] **Step 9: Commit**

```bash
git add fe/lib fe/test
git commit -m "Show a phone number where the client used to show a username"
```

---

### Task 6: Jatuhkan `username`

Langkah *contract*. Tidak ada lagi yang menyebutnya.

**Files:**
- Create: `be/database/migrations/2026_08_22_100002_drop_username_from_users_table.php`
- Modify: `be/app/Models/User.php` (`$fillable`, `toPublicArray()`)

**Interfaces:**
- Consumes: Task 2, 3, 4, 5 — tidak ada kode yang membaca atau menulis `username`.
- Produces: kolom `users.username` tidak ada lagi; `toPublicArray()` mengembalikan `phone` dan tidak lagi `username`.

- [ ] **Step 1: Pastikan tidak ada yang menyebutnya**

Run: `cd /e/deepCT-gemini && grep -rn "username" be/app be/tests be/database/seeders fe/lib fe/test`
Expected: tidak ada keluaran. Bila ada, tangani dulu — menjatuhkan kolom yang masih dibaca akan menghasilkan 500 saat berjalan, bukan kegagalan test.

- [ ] **Step 2: Tulis migrasinya**

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The last step of replacing `username` with `phone`.
 *
 * Nothing reads or writes this column any more — writers moved first, then
 * readers, then the client, each in its own commit with a green suite behind
 * it. What is left is dropping it.
 *
 * **This destroys data.** Every username is gone, here and on the VPS at
 * deploy time. `down()` can bring the column back but not its contents: it
 * refills with `user{id}` purely so the unique constraint can go back on. A
 * rollback is therefore lossy, and there is nothing that can be done about
 * that — the values exist nowhere else.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('username');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable()->after('id');
        });

        // Not the original values. Those are gone.
        DB::table('users')->update(['username' => DB::raw("CONCAT('user', id)")]);

        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable(false)->change();
            $table->unique('username');
        });
    }
};
```

- [ ] **Step 3: Buang dari model**

Di `be/app/Models/User.php`, hapus `'username',` dari `$fillable` dan `'username' => $this->username,` dari `toPublicArray()`.

- [ ] **Step 4: Jalankan migrasi dan seluruh test**

Run: `cd be && php artisan migrate && php artisan test`
Expected: migrasi DONE, 257 test lulus.

- [ ] **Step 5: Buktikan lewat server yang berjalan**

Run: `cd be && npm run octane:reset`

Lalu, dengan token admin yang sah:

```bash
curl -s -H "Authorization: Bearer <token>" -H "Accept: application/json" \
  http://127.0.0.1:8000/api/admin/users | head -c 500
```

Expected: setiap user punya `phone`, tidak ada satu pun `username`. `route:list` bukan bukti; ini bukti.

- [ ] **Step 6: Commit**

```bash
git add be/database/migrations/2026_08_22_100002_drop_username_from_users_table.php be/app/Models/User.php
git commit -m "Drop username now that nothing names it"
```

---

### Task 7: `max_concurrent_jobs` dihapus

**Files:**
- Create: `be/database/migrations/2026_08_22_100003_drop_max_concurrent_jobs_from_models_table.php`
- Modify: `be/app/Models/Model.php` (`$fillable`)
- Modify: `be/app/Http/Controllers/API/ModelController.php:65,82,142,152,153,166`
- Modify: `be/database/seeders/DefaultModelSeeder.php:37`
- Modify: `be/tests/Feature/` — 6 berkas yang memasang `'max_concurrent_jobs' => 1`
- Modify: `fe/lib/models/model_info.dart`
- Modify: `fe/lib/services/admin_model_service.dart:103,132`
- Modify: `fe/lib/screens/admin/model_management_screen.dart:392`

**Interfaces:**
- Consumes: tidak ada.
- Produces: kolom `models.max_concurrent_jobs` tidak ada lagi; `ModelInfo.maxConcurrentJobs` dan `ModelInfo.isAtCapacity` tidak ada lagi. `models.current_jobs_count` **tetap ada dan tetap dipakai**.

- [ ] **Step 1: Buang penyebutnya di backend**

Di `be/app/Http/Controllers/API/ModelController.php`, hapus baris `'max_concurrent_jobs' => 'nullable|integer|min:1|max:10',` di baris 65 dan 142; hapus `'max_concurrent_jobs' => $request->input('max_concurrent_jobs', 1),` di baris 82; dan buang `'max_concurrent_jobs'` dari ketiga daftar `only([...])` di baris 152, 153 dan 166.

Di `be/app/Models/Model.php`, hapus `'max_concurrent_jobs',` dari `$fillable`. **Biarkan `'current_jobs_count',`** — ia dinaikkan di `ProcessDeepLearningImage.php:69`, diturunkan di baris 142, dan dibaca `ModelController.php:190,227` untuk menolak penghapusan model yang sedang sibuk.

Di `be/database/seeders/DefaultModelSeeder.php:37`, hapus barisnya.

- [ ] **Step 2: Buang dari berkas test**

Run: `cd be && grep -rn "max_concurrent_jobs" tests/`

Enam berkas memasang `'max_concurrent_jobs' => 1` saat membuat model. Buang barisnya di setiap tempat. Aturan yang sama seperti Task 4: buang kuncinya, jangan sentuh apa pun yang lain.

- [ ] **Step 3: Tulis migrasinya**

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A column that never did anything.
 *
 * `max_concurrent_jobs` appeared in validation rules, in `$fillable`, in the
 * seeder and in tests — and was never compared against anything, anywhere in
 * `app/`. The intent is legible enough: do not send more than N jobs at once
 * to one worker. The limiter was simply never written, so what the column
 * actually did was promise a control that did not exist.
 *
 * Its sibling `current_jobs_count` stays, because that one works: it is
 * incremented when a job starts, decremented when it ends, and read to refuse
 * deleting a model that is busy.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->dropColumn('max_concurrent_jobs');
        });
    }

    public function down(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->integer('max_concurrent_jobs')->default(1)->after('last_health_check');
        });
    }
};
```

- [ ] **Step 4: Jalankan migrasi dan test backend**

Run: `cd be && php artisan migrate && php artisan test`
Expected: migrasi DONE, 257 test lulus.

- [ ] **Step 5: Buang dari Flutter**

Di `fe/lib/models/model_info.dart`: hapus field `final int maxConcurrentJobs;`, parameter `required this.maxConcurrentJobs,`, pembacaan `maxConcurrentJobs: _toInt(json['max_concurrent_jobs'], 1),`, dan getter `isAtCapacity` beserta komentarnya.

Di `fe/lib/services/admin_model_service.dart`, hapus parameter `maxConcurrentJobs` dan kedua baris payload di 103 dan 132.

Di `fe/lib/screens/admin/model_management_screen.dart`, blok `_kv` yang menampilkan jumlah pekerjaan menjadi:

```dart
                  _kv(context, 'Jobs running', '${model.currentJobsCount}'),
```

Label diubah dari `'Jobs'`: `2 / 5` membaca sebagai pecahan dari sebuah batas, dan batas itu sudah tidak ada. `Jobs running: 2` mengatakan apa adanya.

- [ ] **Step 6: Analisa dan test Flutter**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 144 test lulus.

- [ ] **Step 7: Commit**

```bash
git add be/database/migrations/2026_08_22_100003_drop_max_concurrent_jobs_from_models_table.php be/app be/database/seeders be/tests fe/lib
git commit -m "Delete a column that promised a limit nobody enforced"
```

---

### Task 8: Lencana status membaca label ramah

Diikutkan ke B1 karena `model_info.dart` dan `model_management_screen.dart` memang sudah dibuka di Task 7.

**Files:**
- Modify: `fe/lib/models/model_status_message.dart`
- Modify: `fe/lib/screens/user/upload_screen.dart` — lencana `_ModelOption`
- Test: `fe/test/model_status_message_test.dart`

**Interfaces:**
- Consumes: `modelStatusMessage(String? reason)` dari bagian A.
- Produces: `modelStatusLabel(String status)` mengembalikan `'ONLINE'`, `'SLOW'`, `'OFFLINE'`.

- [ ] **Step 1: Tulis test yang gagal**

Tambahkan ke `fe/test/model_status_message_test.dart`:

```dart
  test('a slow worker is labelled SLOW, not TROUBLE', () {
    // The badge rendered status.toUpperCase(), so a worker answering slowly
    // read "TROUBLE" right beside a sentence saying "answering slowly" —
    // the same shape of jargon part A removed from the copy.
    expect(modelStatusLabel('trouble'), 'SLOW');
  });

  test('the other two statuses keep the words people already know', () {
    expect(modelStatusLabel('online'), 'ONLINE');
    expect(modelStatusLabel('offline'), 'OFFLINE');
  });

  test('an unknown status is shown as given rather than hidden', () {
    // A status this build has not heard of is worth seeing, not swallowing.
    expect(modelStatusLabel('quarantined'), 'QUARANTINED');
  });
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `cd fe && flutter test test/model_status_message_test.dart`
Expected: FAIL — `Method not found: 'modelStatusLabel'`.

- [ ] **Step 3: Tulis fungsinya**

Tambahkan ke `fe/lib/models/model_status_message.dart`:

```dart
/// The word shown on a model's status badge.
///
/// `trouble` is the database's word and a poor one for a badge: it sits
/// beside a sentence explaining the worker is merely answering slowly, and
/// reads as something far worse. The other two need no translation.
///
/// Anything unrecognised is upper-cased and shown as-is. A status this build
/// has not heard of is worth seeing rather than swallowing.
String modelStatusLabel(String status) =>
    status == 'trouble' ? 'SLOW' : status.toUpperCase();
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `cd fe && flutter test test/model_status_message_test.dart`
Expected: PASS, 9 test.

- [ ] **Step 5: Pakai di lencana**

Di `fe/lib/screens/user/upload_screen.dart`, di dalam `_ModelOption.build`, ganti:

```dart
                  model.status.toUpperCase(),
```

menjadi:

```dart
                  modelStatusLabel(model.status),
```

`modelStatusMessage` sudah diimpor dari berkas yang sama, jadi tidak ada import baru.

- [ ] **Step 6: Analisa dan test**

Run: `cd fe && flutter analyze && flutter test`
Expected: analyze bersih, 147 test lulus.

- [ ] **Step 7: Commit**

```bash
git add fe/lib/models/model_status_message.dart fe/lib/screens/user/upload_screen.dart fe/test/model_status_message_test.dart
git commit -m "Call a slow worker SLOW on the badge too, not TROUBLE"
```

---

### Task 9: Catat dan centang

**Files:**
- Modify: `ARCHITECTURE.md` — daftar kolom `users` dan `models`
- Modify: `CHANGELOG.md`
- Modify: `ROADMAP.md` §12 item B1

- [ ] **Step 1: Verifikasi penuh**

```bash
cd be && php artisan test
cd ../fe && flutter analyze
flutter test
flutter build apk --release
```

Catat angka yang benar-benar keluar.

- [ ] **Step 2: Perbaiki `ARCHITECTURE.md`**

Daftar kolom `models` di sekitar baris 126-128 menyebut `max_concurrent_jobs`, yang sudah tidak ada, dan **belum** menyebut `health_check_reason`, yang ditambahkan di bagian A dan terlewat saat itu. Perbaiki keduanya:

```
`name`, `version`, `endpoint_url`, `status` (enum online/offline/trouble),
`is_active`, `last_health_check`, `health_check_error`, `health_check_reason`,
`current_jobs_count`, `total_predictions`, `accuracy`, `deployed_at`.
```

Perbarui juga daftar kolom `users` di dokumen yang sama: `username` diganti `phone`.

- [ ] **Step 3: Tulis entri CHANGELOG**

Di puncak `CHANGELOG.md`, mengikuti bentuk entri yang ada. Sebutkan **mengapa**: `username` adalah kolom ketiga yang tidak mengidentifikasi apa pun yang belum teridentifikasi, dan `NOT NULL` + `unique` memaksa setiap pembuatan akun mengarang satu — dua metode di `AccessRequestController` ada semata untuk itu. Sebutkan juga bahwa empat "fallback" nama ternyata tidak pernah berjalan karena `users.name` tidak nullable, dan bahwa `max_concurrent_jobs` tidak pernah dibandingkan dengan apa pun.

Katakan terus terang bahwa rollback bersifat merusak.

- [ ] **Step 4: Centang ROADMAP**

Ubah `- [ ] **B1 — Pembersihan skema.**` menjadi `- [x]`, dengan angka yang benar-benar diamati dan daftar apa yang **tidak** dikerjakan — termasuk bahwa migrasi belum dijalankan di VPS.

- [ ] **Step 5: Commit**

```bash
git add ARCHITECTURE.md CHANGELOG.md ROADMAP.md
git commit -m "Record what part B1 changed and why"
```

---

## Catatan untuk pelaksana

**Urutan Task 1 sampai 6 tidak boleh diacak.** Itu urutan *expand-migrate-contract*, dan satu-satunya alasan ada titik hijau di tengah pekerjaan. Task 2 dan 3 meninggalkan suite merah di berkas test; Task 4 menutupnya. Bila commit merah mengganggu, kerjakan 2, 3 dan 4 lalu commit sekali.

**Task 7 dan 8 tidak bergantung pada 1-6** dan boleh dikerjakan lebih dulu.

**Satu hal yang ditemukan saat rencana ini disusun dan bukan bagian dari spec:** `ARCHITECTURE.md` belum menyebut `health_check_reason` yang ditambahkan di bagian A. Task 9 membetulkannya.
