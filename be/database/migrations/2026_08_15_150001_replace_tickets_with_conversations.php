<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Support stops being a ticket system and becomes messaging.
 *
 * The ticket model asked a researcher with a problem to first classify it:
 * pick a subject, a category, a priority, then track its status. That is the
 * shape of a helpdesk with a support department behind it. Here there is one
 * administrator, and what people actually want is to say "this is broken" and
 * get an answer — so the whole ceremony is dropped and what is left is a
 * conversation, one per account, exactly like a chat.
 *
 * Gone with it: `subject`, `category`, `priority`, `status`, `awaiting_admin`,
 * `resolved_at`, `resolved_by`, `analysis_record_id`. What remains is who is
 * talking, when they last spoke, and whether the administrator has filed the
 * thread away.
 *
 * The old rows are carried over rather than dropped: several tickets from the
 * same person collapse into that person's single thread, and each ticket's
 * subject is folded into the first message it carried so nothing anyone wrote
 * is lost.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('conversations', function (Blueprint $table) {
            $table->id();

            // One thread per account, which is what `unique` enforces. Guests
            // have no account, and MySQL allows any number of NULLs in a
            // unique index, so each of them gets a thread of their own.
            $table->foreignId('user_id')->nullable()->unique()
                ->constrained()->cascadeOnDelete();

            // Set instead of user_id when the message came from the sign-in
            // page, where the sender is by definition not signed in.
            $table->string('guest_name', 100)->nullable();
            $table->string('guest_email', 150)->nullable();

            // Denormalised so the inbox can sort by activity without joining
            // every thread's messages.
            $table->timestamp('last_message_at')->nullable();

            // The administrator's only organising tool, replacing a four-state
            // status enum: out of the inbox, not deleted.
            $table->boolean('is_archived')->default(false);

            $table->timestamps();

            $table->index(['is_archived', 'last_message_at']);
        });

        Schema::create('messages', function (Blueprint $table) {
            $table->id();

            $table->foreignId('conversation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();

            $table->text('body');

            // Recorded at write time rather than derived from the author's
            // current role: someone promoted to administrator later must not
            // have their old messages turn into staff replies retroactively.
            $table->boolean('from_admin')->default(false);

            // When the *other* side read it. Every message has exactly one
            // recipient side, so one column is enough for both directions.
            $table->timestamp('read_at')->nullable();

            $table->timestamps();

            $table->index(['conversation_id', 'created_at']);
            $table->index(['from_admin', 'read_at']);
        });

        if (Schema::hasTable('support_tickets')) {
            $this->carryOverTickets();

            Schema::dropIfExists('support_ticket_messages');
            Schema::dropIfExists('support_tickets');
        }
    }

    /**
     * Move existing tickets into threads.
     *
     * Several tickets from one person become one conversation, since that is
     * the whole point of the change. Their subjects are prepended to the first
     * message of each so the text survives the columns being dropped.
     */
    private function carryOverTickets(): void
    {
        $tickets = DB::table('support_tickets')->orderBy('id')->get();

        if ($tickets->isEmpty()) {
            return;
        }

        // Grouped by account; a guest ticket has no account, so it groups only
        // with itself.
        $groups = [];
        foreach ($tickets as $ticket) {
            $key = $ticket->user_id !== null ? "u{$ticket->user_id}" : "g{$ticket->id}";
            $groups[$key][] = $ticket;
        }

        /** @var array<int,int> $conversationOf ticket id => conversation id */
        $conversationOf = [];
        /** @var array<int,string|null> $subjectOf ticket id => its subject */
        $subjectOf = [];

        foreach ($groups as $rows) {
            $first = $rows[0];

            $conversationId = DB::table('conversations')->insertGetId([
                'user_id' => $first->user_id,
                'guest_name' => $first->guest_name ?? null,
                'guest_email' => $first->guest_email ?? null,
                'last_message_at' => collect($rows)->max('last_reply_at'),
                // Only filed away if every ticket that fed this thread was
                // finished; one open ticket keeps the whole thread in view.
                'is_archived' => collect($rows)->every(
                    fn($r) => in_array($r->status, ['resolved', 'closed'], true)
                ),
                'created_at' => $first->created_at,
                'updated_at' => now(),
            ]);

            foreach ($rows as $row) {
                $conversationOf[$row->id] = $conversationId;
                $subjectOf[$row->id] = $row->subject ?? null;
            }
        }

        $seenTicket = [];

        foreach (DB::table('support_ticket_messages')->orderBy('id')->get() as $message) {
            $ticketId = $message->support_ticket_id;

            if (!isset($conversationOf[$ticketId])) {
                continue;
            }

            $body = $message->body;

            // The first message of a ticket inherits its subject line, so a
            // thread still reads as what it was about.
            if (!isset($seenTicket[$ticketId])) {
                $seenTicket[$ticketId] = true;
                $subject = trim((string) ($subjectOf[$ticketId] ?? ''));

                if ($subject !== '') {
                    $body = "{$subject}\n\n{$body}";
                }
            }

            DB::table('messages')->insert([
                'conversation_id' => $conversationOf[$ticketId],
                'user_id' => $message->user_id,
                'body' => $body,
                'from_admin' => $message->from_admin,
                'read_at' => null,
                'created_at' => $message->created_at,
                'updated_at' => $message->updated_at,
            ]);
        }
    }

    /**
     * Lossy on purpose.
     *
     * Subject, category, priority and status no longer exist anywhere, so
     * rolling back rebuilds the tables and returns each thread as a single
     * ticket. There is nothing left to reconstruct them from.
     */
    public function down(): void
    {
        Schema::create('support_tickets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->cascadeOnDelete();
            $table->string('guest_name', 100)->nullable();
            $table->string('guest_email', 150)->nullable();
            $table->string('subject');
            $table->string('category', 50)->default('other');
            $table->enum('status', ['open', 'in_progress', 'resolved', 'closed'])->default('open');
            $table->enum('priority', ['low', 'normal', 'high'])->default('normal');
            $table->foreignId('analysis_record_id')->nullable()
                ->constrained('analysis_records')->nullOnDelete();
            $table->timestamp('last_reply_at')->nullable();
            $table->boolean('awaiting_admin')->default(true);
            $table->timestamp('resolved_at')->nullable();
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('support_ticket_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('support_ticket_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->text('body');
            $table->boolean('from_admin')->default(false);
            $table->timestamps();
        });

        foreach (DB::table('conversations')->orderBy('id')->get() as $conversation) {
            $ticketId = DB::table('support_tickets')->insertGetId([
                'user_id' => $conversation->user_id,
                'guest_name' => $conversation->guest_name,
                'guest_email' => $conversation->guest_email,
                'subject' => 'Support conversation',
                'category' => 'other',
                'status' => $conversation->is_archived ? 'closed' : 'open',
                'priority' => 'normal',
                'last_reply_at' => $conversation->last_message_at,
                'awaiting_admin' => false,
                'created_at' => $conversation->created_at,
                'updated_at' => $conversation->updated_at,
            ]);

            DB::table('messages')
                ->where('conversation_id', $conversation->id)
                ->orderBy('id')
                ->each(function ($message) use ($ticketId) {
                    DB::table('support_ticket_messages')->insert([
                        'support_ticket_id' => $ticketId,
                        'user_id' => $message->user_id,
                        'body' => $message->body,
                        'from_admin' => $message->from_admin,
                        'created_at' => $message->created_at,
                        'updated_at' => $message->updated_at,
                    ]);
                });
        }

        Schema::dropIfExists('messages');
        Schema::dropIfExists('conversations');
    }
};
