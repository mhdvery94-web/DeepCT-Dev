<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * In-app notifications.
 *
 * Deliberately Laravel's own schema, not a hand-rolled one, so `$user->notify()`
 * and `$user->unreadNotifications` work as documented — and so that sending the
 * same notification by email later is a one-word change to `via()` rather than
 * a second delivery system.
 *
 * Distinct from `user_activities`, which is an audit trail: that records what
 * happened for an administrator to inspect afterwards, this tells one person
 * something they need to act on now. The same event can produce both.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('type');
            $table->morphs('notifiable');
            $table->text('data');
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            // The bell polls unread counts, and that query is the one that has
            // to stay cheap.
            $table->index(['notifiable_type', 'notifiable_id', 'read_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
