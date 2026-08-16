<?php

namespace App\Services;

use App\Models\AccessRequest;
use App\Models\AnalysisRecord;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\Model;
use App\Models\User;
use App\Notifications\PlatformNotification;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

/**
 * Every notification the platform can send, in one file.
 *
 * Written as named events rather than a generic `notify($user, $text)` so that
 * the wording of, say, a failed prediction lives in one place instead of being
 * retyped at each call site — and so this file answers "what does the platform
 * ever tell people?" on its own.
 *
 * **Nothing here may break its caller.** A notification is a courtesy on top of
 * work that has already succeeded: a prediction that finished must not be
 * marked failed because writing a row about it threw. Everything therefore goes
 * through [push], which swallows and logs.
 */
class Notifier
{
    // ------------------------------------------------------------- messaging

    /** A researcher wrote in. Goes to every administrator. */
    public static function messageFromUser(Conversation $conversation, Message $message): void
    {
        $name = $conversation->displayName();

        self::push(
            self::admins(),
            type: 'message.received',
            title: "New message from {$name}",
            body: self::preview($message->body),
            link: 'messages',
            meta: ['conversation_id' => $conversation->id],
        );
    }

    /**
     * Someone who could not sign in wrote from the sign-in page.
     *
     * Called out separately from [messageFromUser] because there is no
     * account behind this thread to put an in-app notice on, and this
     * platform sends no email — the notification pushed here is the only
     * prompt an administrator gets. They can still reply in-app the normal
     * way; the reply just sits in the thread, unseen, until the sender gets
     * an account and signs in with the address they gave, at which point
     * `Conversation::adoptGuestThreadsFor()` merges the thread into theirs.
     */
    public static function messageFromGuest(Conversation $conversation, Message $message): void
    {
        self::push(
            self::admins(),
            type: 'message.guest',
            title: "Message from {$conversation->guest_name} (no account)",
            body: self::preview($message->body) . ' — no account yet; a reply '
                . 'here is only seen once they sign in as '
                . $conversation->guest_email,
            link: 'messages',
            meta: ['conversation_id' => $conversation->id],
        );
    }

    /** An administrator replied. Goes to the researcher who asked. */
    public static function messageFromAdmin(Conversation $conversation, Message $message): void
    {
        if (!$conversation->user) {
            // A guest thread has nobody signed in to notify, and there is no
            // email fallback — this is a deliberate silent no-op, not a gap.
            // The reply itself is still saved on the thread and reaches them
            // once they get an account and sign in with the address they
            // gave (see adoptGuestThreadsFor()).
            return;
        }

        self::push(
            collect([$conversation->user]),
            type: 'message.reply',
            title: 'Support replied',
            body: self::preview($message->body),
            link: 'messages',
            meta: ['conversation_id' => $conversation->id],
        );
    }

    // ----------------------------------------------------------- predictions

    public static function predictionCompleted(AnalysisRecord $record, int $frames): void
    {
        if (!$record->user_id) {
            return;
        }

        self::push(
            self::user($record->user_id),
            type: 'prediction.completed',
            title: 'Interpolation finished',
            body: "{$frames} frame(s) generated for {$record->file_name}. "
                . 'Results are deleted 24 hours after they are produced.',
            link: "predictions/{$record->id}",
            meta: ['analysis_record_id' => $record->id, 'job_id' => $record->job_id],
        );
    }

    public static function predictionFailed(AnalysisRecord $record, string $error): void
    {
        if (!$record->user_id) {
            return;
        }

        self::push(
            self::user($record->user_id),
            type: 'prediction.failed',
            title: 'Interpolation failed',
            body: self::preview($error),
            link: "predictions/{$record->id}",
            meta: ['analysis_record_id' => $record->id, 'job_id' => $record->job_id],
        );
    }

    /**
     * Results are about to be deleted.
     *
     * The most expensive thing this platform can do to a researcher is throw
     * away a gigabyte of output they never got told about.
     */
    public static function resultsExpiringSoon(AnalysisRecord $record, int $hours): void
    {
        if (!$record->user_id) {
            return;
        }

        self::push(
            self::user($record->user_id),
            type: 'prediction.expiring',
            title: 'Results expire soon',
            body: "The output of {$record->file_name} is deleted in about "
                . "{$hours} hour(s). Download it before then.",
            link: "predictions/{$record->id}",
            meta: ['analysis_record_id' => $record->id],
        );
    }

    // --------------------------------------------------------------- account

    /** Somebody asked for an account from the landing page. */
    public static function accessRequestSubmitted(AccessRequest $accessRequest): void
    {
        self::push(
            self::admins(),
            type: 'access_request.submitted',
            title: 'New access request',
            body: "{$accessRequest->fullName()} ({$accessRequest->institution}) "
                . 'is asking for an account.',
            link: 'access-requests',
            meta: ['access_request_id' => $accessRequest->id],
        );
    }

    /**
     * Their account exists now.
     *
     * They cannot see this until they sign in, which is exactly when it is
     * useful: the first thing in the bell is confirmation they are in the
     * right place.
     */
    public static function accountApproved(User $user): void
    {
        self::push(
            collect([$user]),
            type: 'account.approved',
            title: 'Your account is ready',
            body: 'Welcome. Change your password from the sidebar, and use IT '
                . 'Support if anything is unclear.',
            link: 'dashboard',
        );
    }

    // ---------------------------------------------------------------- models

    /**
     * The GPU worker stopped answering.
     *
     * Only sent on the *transition* into offline. The health check runs every
     * five minutes, and a model that is down for a day would otherwise produce
     * 288 identical notifications.
     */
    public static function modelWentOffline(Model $model, ?string $error): void
    {
        self::push(
            self::admins(),
            type: 'model.offline',
            title: "Model offline: {$model->name}",
            body: $error ?: 'The endpoint stopped answering. Predictions will '
                . 'queue but cannot run.',
            link: 'models',
            meta: ['model_id' => $model->id],
        );
    }

    public static function modelBackOnline(Model $model): void
    {
        self::push(
            self::admins(),
            type: 'model.online',
            title: "Model back online: {$model->name}",
            body: 'The endpoint is answering again.',
            link: 'models',
            meta: ['model_id' => $model->id],
        );
    }

    // --------------------------------------------------------------- plumbing

    /** @return Collection<int, User> */
    private static function admins(): Collection
    {
        return User::where('role', 'admin')->where('is_active', true)->get();
    }

    /** @return Collection<int, User> */
    private static function user(int $id): Collection
    {
        $user = User::find($id);

        return $user ? collect([$user]) : collect();
    }

    /**
     * Deliver, and never let the delivery take the caller down with it.
     *
     * @param Collection<int, User> $recipients
     */
    private static function push(
        Collection $recipients,
        string $type,
        string $title,
        string $body,
        ?string $link = null,
        array $meta = [],
    ): void {
        if ($recipients->isEmpty()) {
            return;
        }

        try {
            $notification = new PlatformNotification($type, $title, $body, $link, $meta);

            foreach ($recipients as $recipient) {
                $recipient->notify($notification);
            }
        } catch (\Throwable $e) {
            Log::warning("Notification '{$type}' could not be delivered: {$e->getMessage()}");
        }
    }

    /** One line of a message, for a notification body. */
    private static function preview(string $text, int $length = 120): string
    {
        $clean = trim(preg_replace('/\s+/', ' ', $text) ?? '');

        return mb_strimwidth($clean, 0, $length, '...');
    }
}
