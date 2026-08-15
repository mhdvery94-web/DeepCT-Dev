<?php

namespace App\Services;

use RuntimeException;

/**
 * A rejected upload, carrying the HTTP status the API should answer with.
 *
 * Every message is written to be shown to the researcher directly, so it must
 * say what to do rather than what went wrong internally.
 */
class IntakeException extends RuntimeException
{
    public function __construct(string $message, private readonly int $status = 422)
    {
        parent::__construct($message);
    }

    public function status(): int
    {
        return $this->status;
    }
}
