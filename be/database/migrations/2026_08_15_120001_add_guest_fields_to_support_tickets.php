<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Lets someone who is locked out raise a ticket.
 *
 * The "IT Support" button sits on the sign-in page, and the most common reason
 * to press it is not being able to sign in — exactly when an authenticated
 * endpoint is no use. A guest ticket therefore carries the reporter's name and
 * address instead of a user id, and the administrator answers by email.
 *
 * `user_id` is made nullable with a raw MODIFY rather than `->change()`: the
 * column has a foreign key, and MySQL keeps the constraint across a MODIFY that
 * only relaxes nullability. See the same pattern in
 * 2026_08_15_100001_make_legacy_frame_columns_nullable.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE support_tickets MODIFY user_id BIGINT UNSIGNED NULL');

        Schema::table('support_tickets', function (Blueprint $table) {
            $table->string('guest_name', 100)->nullable()->after('user_id');
            $table->string('guest_email', 150)->nullable()->after('guest_name');
        });
    }

    public function down(): void
    {
        Schema::table('support_tickets', function (Blueprint $table) {
            $table->dropColumn(['guest_name', 'guest_email']);
        });

        // Guest tickets have no owner to restore, so they go with the column.
        DB::statement('DELETE FROM support_tickets WHERE user_id IS NULL');
        DB::statement('ALTER TABLE support_tickets MODIFY user_id BIGINT UNSIGNED NOT NULL');
    }
};
