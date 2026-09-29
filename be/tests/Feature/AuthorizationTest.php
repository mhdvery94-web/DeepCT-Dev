<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\AnalysisRecord;
use App\Models\User;
use App\Models\UserActivity;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * The role boundary, and the fact that self-service data is scoped to its
 * owner.
 *
 * These are the assertions that matter most in this codebase: a researcher
 * reaching an admin route, or reading another account's rows, is the failure
 * mode with real consequences.
 */
class AuthorizationTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $researcher;
    private User $otherResearcher;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = $this->makeUser('admin', 'admin@brin.go.id', 'admin');
        $this->researcher = $this->makeUser('researcher', 'researcher@brin.go.id', 'user');
        $this->otherResearcher = $this->makeUser('other', 'other@brin.go.id', 'user');
    }

    private function makeUser(string $name, string $email, string $role): User
    {
        return User::create([
            'name' => ucfirst($name),
            'email' => $email,
            'password' => Hash::make('password123'),
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function tokenAs(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    public static function adminRoutes(): array
    {
        return [
            'list users' => ['GET', '/api/admin/users'],
            'create user' => ['POST', '/api/admin/users'],
            'show user' => ['GET', '/api/admin/users/1'],
            'update user' => ['PUT', '/api/admin/users/1'],
            'delete user' => ['DELETE', '/api/admin/users/1'],
            'toggle user' => ['PATCH', '/api/admin/users/1/toggle'],
            'reset password' => ['POST', '/api/admin/users/1/reset-password'],
            'list models' => ['GET', '/api/admin/models'],
            'create model' => ['POST', '/api/admin/models'],
            'sync models' => ['POST', '/api/admin/models/sync'],
            'delete model' => ['DELETE', '/api/admin/models/1'],
            'health check' => ['POST', '/api/admin/models/1/health-check'],
            'test prediction' => ['POST', '/api/admin/models/1/test'],
            'all activities' => ['GET', '/api/admin/activities'],
            'activity types' => ['GET', '/api/admin/activities/types'],
            'user activities' => ['GET', '/api/admin/users/1/activities'],
        ];
    }

    #[DataProvider('adminRoutes')]
    public function test_a_researcher_cannot_reach_admin_routes(string $method, string $uri): void
    {
        $token = $this->tokenAs($this->researcher);

        $this->apiAs($token)
            ->json($method, $uri)
            ->assertForbidden();
    }

    public function test_an_admin_can_reach_admin_routes(): void
    {
        $token = $this->tokenAs($this->admin);

        $this->apiAs($token)->getJson('/api/admin/users')->assertOk();
        $this->apiAs($token)->getJson('/api/admin/models')->assertOk();
        $this->apiAs($token)->getJson('/api/admin/activities')->assertOk();
    }

    public function test_me_activities_only_returns_the_callers_own_rows(): void
    {
        UserActivity::create([
            'user_id' => $this->researcher->id,
            'activity_type' => 'login',
            'description' => 'mine',
        ]);
        UserActivity::create([
            'user_id' => $this->otherResearcher->id,
            'activity_type' => 'login',
            'description' => 'someone else',
        ]);

        $token = $this->tokenAs($this->researcher);

        $rows = $this->apiAs($token)
            ->getJson('/api/me/activities')
            ->assertOk()
            ->json('data');

        $this->assertNotEmpty($rows);

        foreach ($rows as $row) {
            $this->assertSame(
                $this->researcher->id,
                $row['user_id'],
                'me/activities leaked another account\'s row'
            );
        }
    }

    public function test_me_stats_counts_only_the_callers_own_activity(): void
    {
        foreach (range(1, 3) as $i) {
            UserActivity::create([
                'user_id' => $this->researcher->id,
                'activity_type' => 'login',
                'description' => "mine {$i}",
            ]);
        }
        UserActivity::create([
            'user_id' => $this->otherResearcher->id,
            'activity_type' => 'login',
            'description' => 'not mine',
        ]);

        $token = $this->tokenAs($this->researcher);
        $data = $this->apiAs($token)->getJson('/api/me/stats')->assertOk()->json('data');

        // 3 seeded + 1 from logging in through the real endpoint.
        $this->assertSame(4, $data['activities_total']);
    }

    /**
     * A researcher needs to know whether a model is reachable, but knowing its
     * endpoint URL would let them bypass the platform and call the GPU worker
     * directly.
     */
    public function test_me_models_never_exposes_the_endpoint_url(): void
    {
        Model::create([
            'name' => 'Test Model',
            'version' => 'v1',
            'endpoint_url' => 'https://secret-worker.example/predict',
            'status' => 'online',
            'is_active' => true,
        ]);

        $token = $this->tokenAs($this->researcher);
        $response = $this->apiAs($token)->getJson('/api/me/models')->assertOk();

        $response->assertJsonPath('data.0.name', 'Test Model');
        $response->assertJsonPath('data.0.is_available', true);

        $this->assertStringNotContainsString('secret-worker', $response->getContent());
        $this->assertStringNotContainsString('endpoint_url', $response->getContent());
    }

    public function test_me_models_hides_inactive_models(): void
    {
        Model::create([
            'name' => 'Retired', 'version' => 'v0',
            'endpoint_url' => 'https://x.example/predict',
            'status' => 'offline', 'is_active' => false,
        ]);

        $token = $this->tokenAs($this->researcher);

        $this->apiAs($token)->getJson('/api/me/models')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    /**
     * The refresh button probes rather than re-reading.
     *
     * A status the scheduler wrote a minute ago is exactly what the person
     * pressing refresh is trying to get past, so the endpoint has to reach the
     * model itself and write the new verdict.
     */
    public function test_refreshing_models_probes_the_endpoint(): void
    {
        \Illuminate\Support\Facades\Http::fake([
            '*' => \Illuminate\Support\Facades\Http::response('', 404),
        ]);

        $model = Model::create([
            'name' => 'Test Model', 'version' => 'v1',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'offline', 'is_active' => true,
            'last_health_check' => now()->subMinutes(5),
        ]);

        $token = $this->tokenAs($this->researcher);

        // 404 on the tunnel root means FastAPI answered: only /predict exists.
        $this->apiAs($token)->postJson('/api/me/models/refresh')
            ->assertOk()
            ->assertJsonPath('data.0.is_available', true);

        $this->assertSame('online', $model->fresh()->status);
        \Illuminate\Support\Facades\Http::assertSentCount(1);
    }

    /** A second press moments later reads the first press's answer. */
    public function test_refreshing_twice_does_not_probe_twice(): void
    {
        \Illuminate\Support\Facades\Http::fake([
            '*' => \Illuminate\Support\Facades\Http::response('', 404),
        ]);

        Model::create([
            'name' => 'Test Model', 'version' => 'v1',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'offline', 'is_active' => true,
            'last_health_check' => now()->subMinutes(5),
        ]);

        $token = $this->tokenAs($this->researcher);

        $this->apiAs($token)->postJson('/api/me/models/refresh')->assertOk();
        $this->apiAs($token)->postJson('/api/me/models/refresh')->assertOk();

        \Illuminate\Support\Facades\Http::assertSentCount(1);
    }

    public function test_an_admin_cannot_delete_their_own_account(): void
    {
        $token = $this->tokenAs($this->admin);

        $this->apiAs($token)
            ->deleteJson("/api/admin/users/{$this->admin->id}")
            ->assertForbidden();

        $this->assertNotNull(User::find($this->admin->id));
    }

    public function test_deleting_an_account_removes_prediction_and_upload_files(): void
    {
        Storage::fake('local');
        $model = Model::create([
            'name' => 'Test Model', 'version' => 'v1',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online', 'is_active' => true,
        ]);
        $record = AnalysisRecord::create([
            'user_id' => $this->researcher->id,
            'model_id' => $model->id,
            'job_id' => 'deleted-user-run',
            'input_folder' => "predictions/{$this->researcher->id}/deleted-user-run/input",
            'output_folder' => "predictions/{$this->researcher->id}/deleted-user-run/output",
            'status' => 'completed',
            'expires_at' => now()->addDay(),
        ]);
        Storage::put("{$record->input_folder}/frame_001.tif", 'frame');
        Storage::put("prediction-evidence/{$record->id}/frame_002.png", 'thumbnail');
        Storage::put("temp/uploads/{$this->researcher->id}/unfinished.part", 'chunk');

        $this->apiAs($this->tokenAs($this->admin))
            ->deleteJson("/api/admin/users/{$this->researcher->id}")
            ->assertOk();

        $this->assertSame(0, AnalysisRecord::where('user_id', $this->researcher->id)->count());
        $this->assertSame([], Storage::allFiles("predictions/{$this->researcher->id}"));
        $this->assertSame([], Storage::allFiles("prediction-evidence/{$record->id}"));
        $this->assertSame([], Storage::allFiles("temp/uploads/{$this->researcher->id}"));
    }

    public function test_an_account_with_a_running_prediction_cannot_be_deleted(): void
    {
        $model = Model::create([
            'name' => 'Test Model', 'version' => 'v1',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online', 'is_active' => true,
        ]);
        AnalysisRecord::create([
            'user_id' => $this->researcher->id,
            'model_id' => $model->id,
            'job_id' => 'running-user-run',
            'input_folder' => "predictions/{$this->researcher->id}/running-user-run/input",
            'output_folder' => "predictions/{$this->researcher->id}/running-user-run/output",
            'status' => 'processing',
            'expires_at' => now()->addDay(),
        ]);

        $this->apiAs($this->tokenAs($this->admin))
            ->deleteJson("/api/admin/users/{$this->researcher->id}")
            ->assertStatus(409);

        $this->assertNotNull($this->researcher->fresh());
    }

    public function test_disabling_an_account_revokes_its_existing_tokens(): void
    {
        $researcherToken = $this->tokenAs($this->researcher);
        $adminToken = $this->tokenAs($this->admin);

        $this->apiAs($adminToken)
            ->patchJson("/api/admin/users/{$this->researcher->id}/toggle")
            ->assertOk();

        $this->assertSame(0, $this->researcher->tokens()->count());
        $this->apiAs($researcherToken)->getJson('/api/user')->assertUnauthorized();
    }

    public function test_admin_password_reset_revokes_existing_tokens(): void
    {
        $researcherToken = $this->tokenAs($this->researcher);
        $adminToken = $this->tokenAs($this->admin);

        $this->apiAs($adminToken)
            ->postJson("/api/admin/users/{$this->researcher->id}/reset-password")
            ->assertOk();

        $this->assertSame(0, $this->researcher->tokens()->count());
        $this->apiAs($researcherToken)->getJson('/api/user')->assertUnauthorized();
    }

    public function test_an_admin_cannot_deactivate_their_own_account(): void
    {
        $token = $this->tokenAs($this->admin);

        $this->apiAs($token)
            ->patchJson("/api/admin/users/{$this->admin->id}/toggle")
            ->assertForbidden();

        $this->assertTrue((bool) User::find($this->admin->id)->is_active);
    }
}
