<?php

namespace App\Notifications;

use Illuminate\Notifications\Notification;

/**
 * Every in-app notification, in one class.
 *
 * Laravel's convention is a class per event, which would be a dozen files that
 * differ only in their strings. What actually varies is the payload, so the
 * payload is the constructor and the semantics live in {@see \App\Services\Notifier}
 * — one file where every notification the platform can send is visible at once.
 *
 * `via()` returns `database` only. When mail is configured, adding `'mail'`
 * here and a `toMail()` is the whole change; that is the reason for using the
 * framework's notification system rather than inserting rows by hand.
 */
class PlatformNotification extends Notification
{
    /**
     * @param string $type  dotted event name, e.g. `message.received`
     * @param string $title one short line — this is what the bell shows
     * @param string $body  the detail under it
     * @param string|null $link where tapping it should go, as the client
     *        understands it: `messages`, `predictions/12`, `access-requests`
     * @param array $meta extra ids the client may want, never displayed
     */
    public function __construct(
        public string $type,
        public string $title,
        public string $body,
        public ?string $link = null,
        public array $meta = [],
    ) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['database'];
    }

    /** @return array<string, mixed> */
    public function toDatabase(object $notifiable): array
    {
        return [
            'type' => $this->type,
            'title' => $this->title,
            'body' => $this->body,
            'link' => $this->link,
            'meta' => $this->meta,
        ];
    }
}
