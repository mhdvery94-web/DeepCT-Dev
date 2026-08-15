<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Requests for platform access, submitted from the public landing page.
 *
 * There is no self-registration: an administrator reviews each request and,
 * on approval, an account is created. This table is the queue in between.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('access_requests', function (Blueprint $table) {
            $table->id();

            $table->string('first_name');
            $table->string('last_name');
            $table->string('email');
            $table->string('institution');
            $table->text('reason')->nullable();

            $table->enum('status', ['pending', 'approved', 'rejected'])
                ->default('pending');

            // Why it was rejected, or any note the reviewer left.
            $table->text('review_note')->nullable();

            $table->foreignId('reviewed_by')->nullable()
                ->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();

            // The account created on approval, so the two stay linked.
            $table->foreignId('created_user_id')->nullable()
                ->constrained('users')->nullOnDelete();

            $table->string('ip_address', 45)->nullable();

            $table->timestamps();

            // The admin list is filtered by status and read newest-first.
            $table->index(['status', 'created_at']);

            // Not unique: a rejected applicant may legitimately reapply, and a
            // hard constraint would leave them with no way through.
            $table->index('email');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('access_requests');
    }
};
