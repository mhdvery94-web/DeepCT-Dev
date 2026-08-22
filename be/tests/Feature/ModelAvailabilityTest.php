<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Which models a researcher is allowed to send work to, and what they are
 * told about the ones they are not.
 */
class ModelAvailabilityTest extends TestCase
{
    use RefreshDatabase;

    private User $researcher;

    protected function setUp(): void
    {
        parent::setUp();

        $this->researcher = User::create([
            'name' => 'Researcher',
            'email' => 'researcher@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'is_active' => true,
        ]);
    }

    private function token(): string
    {
        return $this->tokenFor($this->researcher->email, 'password123');
    }

    private function model(array $overrides = []): Model
    {
        return Model::create(array_merge([
            'name' => 'deepCT TC-D',
            'version' => 'v1',
            'kind' => 'inference',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online',
            'is_active' => true,
        ], $overrides));
    }

    /**
     * A worker answering slowly is a working worker.
     *
     * The GPU sits in a Kaggle session behind an ngrok tunnel, so a probe
     * crossing five seconds is the ordinary case rather than the exception.
     * Reporting it unavailable took a live model out of the picker entirely.
     */
    public function test_a_slow_model_is_still_offered(): void
    {
        $this->model([
            'name' => 'Slow worker',
            'status' => 'trouble',
            'health_check_error' => 'Slow response: 7213ms',
            'health_check_reason' => 'slow',
        ]);

        $this->apiAs($this->token())->getJson('/api/me/models')
            ->assertOk()
            ->assertJsonPath('data.0.is_available', true)
            ->assertJsonPath('data.0.health_check_reason', 'slow');
    }

    public function test_a_dead_model_is_not_offered(): void
    {
        $this->model([
            'status' => 'offline',
            'health_check_error' => 'Tunnel is not running (ERR_NGROK_3200)',
            'health_check_reason' => 'tunnel_down',
        ]);

        $this->apiAs($this->token())->getJson('/api/me/models')
            ->assertOk()
            ->assertJsonPath('data.0.is_available', false)
            ->assertJsonPath('data.0.health_check_reason', 'tunnel_down');
    }

    /**
     * The picker selects the first available model on its own, so order is a
     * behaviour and not a presentation detail: a healthy worker sorting below
     * a slow one means every upload goes to the slow one by default.
     */
    public function test_a_healthy_model_sorts_above_a_slow_one(): void
    {
        // Created slow-first, and named so that ordering by name alone would
        // also put the slow one first. Only status ordering can pass this.
        $this->model([
            'name' => 'Alpha',
            'status' => 'trouble',
            'health_check_reason' => 'slow',
        ]);
        $this->model(['name' => 'Zulu', 'status' => 'online']);

        $this->apiAs($this->token())->getJson('/api/me/models')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Zulu')
            ->assertJsonPath('data.1.name', 'Alpha');
    }

    /**
     * A Guzzle failure message carries the URL it failed to reach, and
     * `cleanMessage()` only trims the message's length — it does not remove
     * the host. Sending that to a researcher hands over the very address
     * `models()` withholds `endpoint_url` to protect.
     */
    public function test_a_failure_message_does_not_leak_the_worker_hostname(): void
    {
        $this->model([
            'status' => 'offline',
            'endpoint_url' => 'https://secret-worker.ngrok-free.dev/predict',
            'health_check_error' =>
                'cURL error 7: Failed to connect to secret-worker.ngrok-free.dev port 443',
            'health_check_reason' => 'unreachable',
        ]);

        $response = $this->apiAs($this->token())->getJson('/api/me/models')
            ->assertOk();

        $this->assertStringNotContainsString(
            'secret-worker',
            $response->getContent()
        );
        // The reason code says everything the researcher needs and carries no
        // address at all.
        $response->assertJsonPath('data.0.health_check_reason', 'unreachable');
    }
}
