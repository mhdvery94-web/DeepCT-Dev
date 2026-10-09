<?php

namespace App\Services;

final class PhoneNumber
{
    /** Compare formatting consistently; Indonesian 08... and +628... agree. */
    public static function normalize(?string $value): ?string
    {
        if (!preg_match('/^[+0-9()\s.-]+$/D', (string) $value)) {
            return null;
        }
        $digits = preg_replace('/\D+/', '', (string) $value);
        if (str_starts_with($digits, '00')) {
            $digits = substr($digits, 2);
        }
        if (str_starts_with($digits, '0')) {
            $digits = '62' . substr($digits, 1);
        }
        return strlen($digits) >= 8 && strlen($digits) <= 15 ? $digits : null;
    }
}
