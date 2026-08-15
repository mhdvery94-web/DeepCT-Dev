<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    /**
     * Send the next request as the holder of [$token].
     *
     * Always go through this rather than `withHeader('Authorization', …)`
     * directly. Laravel's AuthManager caches the resolved guard *and the user
     * on it* for the lifetime of a test method, so a second request inside the
     * same test skips token verification entirely. A token revoked mid-test
     * would keep returning 200 and the test would pass while asserting nothing.
     *
     * Verified: after a logout the token row is gone from the database, yet
     * `/api/user` still answered 200 until `forgetGuards()` was called.
     *
     * Pass null to send the request anonymously.
     */
    protected function apiAs(?string $token): static
    {
        $this->app['auth']->forgetGuards();

        if ($token === null) {
            return $this;
        }

        return $this->withHeader('Authorization', "Bearer {$token}");
    }

    /** Log in through the real endpoint and return the bearer token. */
    protected function tokenFor(string $email, string $password): string
    {
        $response = $this->postJson('/api/login', [
            'email' => $email,
            'password' => $password,
        ]);

        $response->assertOk();

        return $response->json('data.token');
    }
}
