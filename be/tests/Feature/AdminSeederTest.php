<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\AdminUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Where the first administrator's password comes from.
 *
 * The interesting case is not the happy one. A deployed machine has run
 * `config:cache`, which freezes config/app.php as it stood at deploy time —
 * SEED_ADMIN_PASSWORD unset, so the cached value is null for ever. An operator
 * then runs `SEED_ADMIN_PASSWORD=... php artisan db:seed --force` and gets a
 * randomly generated password plus a message saying none was supplied, which
 * is the most confusing possible answer to having just supplied one.
 */
class AdminSeederTest extends TestCase
{
    use RefreshDatabase;

    private ?string $saved = null;

    protected function setUp(): void
    {
        parent::setUp();
        $this->saved = $_SERVER['SEED_ADMIN_PASSWORD'] ?? null;
    }

    protected function tearDown(): void
    {
        $this->putEnv($this->saved);
        parent::tearDown();
    }

    /**
     * Set or clear the variable across all three places Laravel reads it from.
     *
     * `unset($_SERVER[...])` alone is not enough and the first draft of this
     * test proved it: a developer machine has SEED_ADMIN_PASSWORD in `.env`,
     * Dotenv publishes it through putenv as well, and `env()` went on finding
     * it there long after $_SERVER had been cleared.
     */
    private function putEnv(?string $value): void
    {
        if ($value === null) {
            unset($_SERVER['SEED_ADMIN_PASSWORD'], $_ENV['SEED_ADMIN_PASSWORD']);
            putenv('SEED_ADMIN_PASSWORD');
            return;
        }

        $_SERVER['SEED_ADMIN_PASSWORD'] = $value;
        $_ENV['SEED_ADMIN_PASSWORD'] = $value;
        putenv("SEED_ADMIN_PASSWORD={$value}");
    }

    private function admin(): User
    {
        return User::where('role', 'admin')->firstOrFail();
    }

    /**
     * The state every deployed machine is in: a cached null, and a variable
     * handed over on the command line a moment ago.
     */
    public function test_the_supplied_password_wins_over_a_stale_config_cache(): void
    {
        config(['app.seed_admin_password' => null]);
        $this->putEnv('chosen-at-the-terminal');

        $this->seed(AdminUserSeeder::class);

        $this->assertTrue(
            Hash::check('chosen-at-the-terminal', $this->admin()->password),
            'the password given on the command line must survive a cached config'
        );
    }

    /** Without a cache in the way, the configured value is still honoured. */
    public function test_the_configured_password_is_used_when_nothing_is_supplied(): void
    {
        $this->putEnv(null);
        config(['app.seed_admin_password' => 'from-the-configuration']);

        $this->seed(AdminUserSeeder::class);

        $this->assertTrue(Hash::check('from-the-configuration', $this->admin()->password));
    }

    /** With neither, one is generated rather than a blank or a default. */
    public function test_a_password_is_generated_when_there_is_none(): void
    {
        $this->putEnv(null);
        config(['app.seed_admin_password' => null]);

        $this->seed(AdminUserSeeder::class);

        $admin = $this->admin();
        $this->assertNotEmpty($admin->password);
        $this->assertFalse(Hash::check('', $admin->password));
        // The one password nobody should ever be handed silently.
        $this->assertFalse(Hash::check('password', $admin->password));
    }

    /** Re-seeding must not fail on the unique email, and must not duplicate. */
    public function test_seeding_twice_updates_rather_than_duplicates(): void
    {
        $this->putEnv('first-one');
        $this->seed(AdminUserSeeder::class);

        $this->putEnv('second-one');
        $this->seed(AdminUserSeeder::class);

        $this->assertSame(1, User::where('role', 'admin')->count());
        $this->assertTrue(Hash::check('second-one', $this->admin()->password));
    }
}
