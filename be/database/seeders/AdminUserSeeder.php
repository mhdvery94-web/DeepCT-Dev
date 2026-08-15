<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Keyed on the unique email so re-seeding is idempotent instead of
        // failing on the unique username/email constraints.

        // Default admin user
        User::updateOrCreate(
            ['email' => 'admin@brin.go.id'],
            [
                'username' => 'admin',
                'name' => 'Administrator',
                'password' => Hash::make('admin123'),
                'role' => 'admin',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );

        // Sample regular user
        User::updateOrCreate(
            ['email' => 'researcher@brin.go.id'],
            [
                'username' => 'researcher',
                'name' => 'Dr. Sample Researcher',
                'password' => Hash::make('user123'),
                'role' => 'user',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
    }
}
