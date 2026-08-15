<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * In-app support: a researcher raises a problem, an administrator answers.
 *
 * Modelled as a conversation rather than a single message. Technical problems
 * almost always need a question back — which frames, what did the error say —
 * and with only one field the administrator would have to leave the app to
 * ask it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('support_tickets', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')->constrained()->cascadeOnDelete();

            $table->string('subject');

            // Free-form rather than an enum: the categories that matter will
            // become clear from use, and an enum here would need a migration
            // to learn anything.
            $table->string('category', 50)->default('other');

            $table->enum('status', ['open', 'in_progress', 'resolved', 'closed'])
                ->default('open');
            $table->enum('priority', ['low', 'normal', 'high'])->default('normal');

            // Set when a job or model is what the ticket is about, so the
            // administrator can jump straight to it.
            $table->foreignId('analysis_record_id')->nullable()
                ->constrained('analysis_records')->nullOnDelete();

            // Denormalised so the list can sort by activity without joining
            // every ticket's messages.
            $table->timestamp('last_reply_at')->nullable();
            $table->boolean('awaiting_admin')->default(true);

            $table->timestamp('resolved_at')->nullable();
            $table->foreignId('resolved_by')->nullable()
                ->constrained('users')->nullOnDelete();

            $table->timestamps();

            $table->index(['status', 'last_reply_at']);
            $table->index(['user_id', 'created_at']);
        });

        Schema::create('support_ticket_messages', function (Blueprint $table) {
            $table->id();

            $table->foreignId('support_ticket_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()
                ->constrained()->nullOnDelete();

            $table->text('body');

            // Recorded at write time rather than derived from the author's
            // current role: someone promoted to admin later must not turn
            // their old messages into staff replies retroactively.
            $table->boolean('from_admin')->default(false);

            $table->timestamps();

            $table->index(['support_ticket_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('support_ticket_messages');
        Schema::dropIfExists('support_tickets');
    }
};
