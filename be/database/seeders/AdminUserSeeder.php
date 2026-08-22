<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * Creates the first administrator.
 *
 * The password comes from the environment, never from this file. A credential
 * committed to a repository is a credential everyone has, and this seeder runs
 * on production too.
 *
 * Set `SEED_ADMIN_PASSWORD` before seeding. Without it a random one is
 * generated and printed once — which is inconvenient exactly often enough that
 * people set the variable.
 */
class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        // The live environment first, the config second, and that order fixes a
        // real failure rather than expressing a preference.
        //
        // Deploys run `config:cache`, which freezes config/app.php as it stood
        // at deploy time — when SEED_ADMIN_PASSWORD was not set, so the cached
        // value is null for ever. Passing it on the command line at seed time
        // then does nothing at all: the seeder generates a random password
        // while reporting that none was given, which is the most confusing
        // possible answer to `SEED_ADMIN_PASSWORD=... php artisan db:seed`.
        //
        // `env()` still resolves against the real process environment when
        // config is cached; it is only the .env *file* that stops being read.
        // So the variable the operator has just typed is visible there, and
        // nowhere else. This is the one place in the application that reads
        // env() outside config/, and this is why.
        $password = env('SEED_ADMIN_PASSWORD') ?: config('app.seed_admin_password');
        $generated = false;

        if (empty($password)) {
            $password = Str::random(20);
            $generated = true;
        }

        // Keyed on the unique email so re-seeding is idempotent instead of
        // failing on the unique email constraint.
        $admin = User::updateOrCreate(
            ['email' => env('SEED_ADMIN_EMAIL') ?: config('app.seed_admin_email', 'admin@brin.go.id')],
            [
                'name' => 'Administrator',
                'password' => Hash::make($password),
                'role' => 'admin',
                'is_active' => true,
                // The first administrator is exempt: there is nobody else to
                // hand them a password, and the one they have is not published.
                'must_change_password' => false,
                'email_verified_at' => now(),
            ]
        );

        if ($generated) {
            $this->command?->newLine();
            $this->command?->warn('  No SEED_ADMIN_PASSWORD was set, so one was generated.');
            $this->command?->line("  <fg=green>{$admin->email}</>  /  <fg=green>{$password}</>");
            $this->command?->line('  This is shown once. Sign in and change it.');
            $this->command?->newLine();
        } else {
            $this->command?->info("  Administrator seeded: {$admin->email}");
        }

        // A sample researcher, for local work only. Seeding one on a public
        // server would hand out a working account nobody asked for.
        if (app()->environment('production')) {
            return;
        }

        User::updateOrCreate(
            ['email' => 'researcher@brin.go.id'],
            [
                'name' => 'Dr. Sample Researcher',
                'password' => Hash::make($password),
                'role' => 'user',
                'is_active' => true,
                'must_change_password' => false,
                'email_verified_at' => now(),
            ]
        );

        $this->command?->info('  Sample researcher seeded (local environments only).');
    }
}
