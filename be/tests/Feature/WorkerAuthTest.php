<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\User;
use App\Services\WorkerRequest;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * The worker has never had a credential.
 *
 * Behind a randomly named tunnel that was security by obscurity and
 * it held. On a workstation at a fixed address on the lab network it holds
 * nothing: anyone on that network can spend the GPU. These tests are about the
 * secret reaching the worker, never reaching a client, and not being wiped by
 * accident.
 */
class WorkerAuthTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private string $token;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::create([
            'name' => 'Administrator',
            'email' => 'admin@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'is_active' => true,
        ]);

        $this->token = $this->tokenFor('admin@brin.go.id', 'password123');
    }

    private function worker(array $attributes = []): Model
    {
        return Model::create($attributes + [
            'name' => 'Workstation',
            'version' => 'v1',
            'endpoint_url' => 'https://worker.example/predict',
            'is_active' => true,
            'status' => 'online',
        ]);
    }

    // ------------------------------------------------- the secret goes out

    public function test_a_registered_secret_is_sent_as_a_bearer_token(): void
    {
        Http::fake(['worker.example/*' => Http::response('ok', 200)]);

        $model = $this->worker(['auth_token' => 'sekali-pakai-rahasia']);

        app(WorkerRequest::class)->for($model, 10)->get($model->endpoint_url);

        Http::assertSent(
            fn($request) =>
                $request->hasHeader('Authorization', 'Bearer sekali-pakai-rahasia')
        );
    }

    public function test_a_worker_without_a_secret_sends_no_authorization(): void
    {
        Http::fake(['worker.example/*' => Http::response('ok', 200)]);

        $model = $this->worker();

        app(WorkerRequest::class)->for($model, 10)->get($model->endpoint_url);

        Http::assertSent(fn($request) => !$request->hasHeader('Authorization'));
    }

    public function test_the_ngrok_header_is_sent_either_way(): void
    {
        // Costs nothing against a worker that is not behind ngrok, and
        // forgetting it against one that is means receiving an HTML
        // interstitial with HTTP 200 where a TIFF was expected.
        Http::fake(['worker.example/*' => Http::response('ok', 200)]);

        $model = $this->worker();

        app(WorkerRequest::class)->for($model, 10)->get($model->endpoint_url);

        Http::assertSent(
            fn($request) => $request->hasHeader('ngrok-skip-browser-warning', 'true')
        );
    }

    /** A trainer reached by config URL has no row to read a secret from. */
    public function test_a_null_model_still_produces_a_usable_request(): void
    {
        Http::fake(['worker.example/*' => Http::response('ok', 200)]);

        app(WorkerRequest::class)->for(null, 10)->get('https://worker.example/train');

        Http::assertSent(fn($request) => !$request->hasHeader('Authorization'));
    }

    // ------------------------------------------- and never comes back out

    public function test_the_secret_is_encrypted_at_rest(): void
    {
        $model = $this->worker(['auth_token' => 'sekali-pakai-rahasia']);

        $stored = \DB::table('models')->where('id', $model->id)->value('auth_token');

        $this->assertNotSame('sekali-pakai-rahasia', $stored);
        $this->assertNotNull($stored);
        // And it still decrypts back through the model.
        $this->assertSame('sekali-pakai-rahasia', $model->fresh()->auth_token);
    }

    public function test_the_registry_never_returns_the_secret(): void
    {
        $this->worker(['auth_token' => 'sekali-pakai-rahasia']);

        $body = $this->apiAs($this->token)
            ->getJson('/api/admin/models')
            ->assertOk()
            ->getContent();

        $this->assertStringNotContainsString('sekali-pakai-rahasia', $body);

        // The quoted key, not the bare word: `has_auth_token` is published on
        // purpose and contains the same letters.
        $this->assertStringNotContainsString('"auth_token"', $body);
        $this->assertStringContainsString('"has_auth_token"', $body);
    }

    public function test_the_registry_says_only_whether_one_is_set(): void
    {
        $with = $this->worker(['auth_token' => 'rahasia', 'name' => 'Protected']);
        $without = $this->worker(['name' => 'Open']);

        $this->assertTrue($with->fresh()->has_auth_token);
        $this->assertFalse($without->fresh()->has_auth_token);
    }

    // --------------------------------------------------- setting and clearing

    public function test_an_administrator_can_register_a_worker_with_a_secret(): void
    {
        $this->apiAs($this->token)
            ->postJson('/api/admin/models', [
                'name' => 'Workstation',
                'version' => 'v1',
                'endpoint_url' => 'https://lab.internal/predict',
                'auth_token' => 'rahasia-lab',
                'verify_tls' => true,
            ])
            ->assertCreated();

        $model = Model::where('name', 'Workstation')->firstOrFail();

        $this->assertSame('rahasia-lab', $model->auth_token);
        $this->assertTrue($model->verify_tls);
    }

    public function test_editing_something_else_leaves_the_secret_alone(): void
    {
        // The regression worth guarding: a form that sends every field would
        // wipe the credential each time somebody fixed a typo in a description.
        $model = $this->worker(['auth_token' => 'rahasia-lab']);

        $this->apiAs($this->token)
            ->putJson("/api/admin/models/{$model->id}", [
                'description' => 'Now with a description',
            ])
            ->assertOk();

        $this->assertSame('rahasia-lab', $model->fresh()->auth_token);
    }

    public function test_an_empty_string_clears_the_secret(): void
    {
        $model = $this->worker(['auth_token' => 'rahasia-lab']);

        $this->apiAs($this->token)
            ->putJson("/api/admin/models/{$model->id}", ['auth_token' => '']);

        $this->assertNull($model->fresh()->auth_token);
        $this->assertFalse($model->fresh()->has_auth_token);
    }

    // ------------------------------------------------------------------ TLS

    public function test_verification_is_off_by_default_as_it_always_was(): void
    {
        // Not a preference — a promise that this change did not switch TLS
        // checking on for an endpoint nobody had tested it against.
        //
        // `fresh()` because the default lives in the database: a create() that
        // never mentions the column leaves the in-memory instance without it,
        // and what is being asserted here is what the column does.
        $this->assertFalse($this->worker()->fresh()->verify_tls);
    }

    public function test_a_worker_can_ask_for_its_certificate_to_be_checked(): void
    {
        $model = $this->worker(['verify_tls' => true]);

        $this->assertTrue($model->fresh()->verify_tls);
    }
}
