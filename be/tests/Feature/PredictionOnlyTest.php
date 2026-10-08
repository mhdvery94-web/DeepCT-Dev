<?php

namespace Tests\Feature;

use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTruncation;
use Illuminate\Foundation\Testing\RefreshDatabaseState;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PredictionOnlyTest extends TestCase
{
    use DatabaseTruncation;

    protected function tearDown(): void
    {
        // DDL tests must not share their data with transaction-based suites.
        RefreshDatabaseState::$migrated = false;
        parent::tearDown();
    }

    public function test_fresh_database_has_only_prediction_models_and_no_managed_training_schema(): void
    {
        foreach (['training_samples', 'training_metrics', 'training_jobs', 'training_datasets'] as $table) {
            $this->assertFalse(Schema::hasTable($table));
        }
        $this->assertFalse(Schema::hasColumn('models', 'kind'));
    }

    public function test_former_routes_are_absent_for_every_role(): void
    {
        foreach ([null, 'admin', 'user'] as $role) {
            $token = $role ? $this->account($role)->createToken('test')->plainTextToken : null;
            foreach (['/api/me/training/jobs', '/api/admin/training/jobs', '/api/admin/training/datasets', '/api/downloads/training/1/weights'] as $path) {
                $this->apiAs($token)->getJson($path)->assertNotFound();
            }
            $this->apiAs($token)->postJson('/api/me/training/jobs', [])->assertNotFound();
            $this->apiAs($token)->postJson('/api/training/worker/claim', [])->assertNotFound();
        }
    }

    public function test_legacy_upgrade_removes_training_without_deleting_predictions_or_inference_models(): void
    {
        $user = $this->account('user');
        $model = Model::create(['name' => 'Inference', 'version' => '1', 'endpoint_url' => 'https://worker.example/predict', 'status' => 'online', 'is_active' => true]);
        $record = AnalysisRecord::create(['user_id' => $user->id, 'model_id' => $model->id, 'job_id' => 'kept-prediction', 'status' => 'completed']);
        $this->restoreLegacySchema();
        $trainer = Model::create(['name' => 'Retired worker', 'version' => '1', 'endpoint_url' => 'https://worker.example/train']);
        DB::table('models')->where('id', $trainer->id)->update(['kind' => 'trainer']);
        $dataset = DB::table('training_datasets')->insertGetId(['name' => 'Retired dataset', 'source_type' => 'upload']);
        DB::table('training_jobs')->insert(['name' => 'Retired run', 'training_dataset_id' => $dataset, 'created_by' => $user->id]);
        DB::table('user_activities')->insert(['user_id' => $user->id, 'activity_type' => 'training_job_created', 'description' => 'Retired']);
        DB::table('user_activities')->insert(['user_id' => $user->id, 'activity_type' => 'prediction_uploaded', 'description' => 'Kept']);

        $migration = require database_path('migrations/2026_10_09_010000_remove_managed_training.php');
        $migration->up();
        $migration->up(); // A restart after partially applied DDL is safe.

        $this->assertDatabaseHas('analysis_records', ['id' => $record->id, 'model_id' => $model->id]);
        $this->assertDatabaseHas('models', ['id' => $model->id]);
        $this->assertDatabaseMissing('models', ['id' => $trainer->id]);
        $this->assertDatabaseHas('users', ['id' => $user->id]);
        $this->assertDatabaseHas('user_activities', ['activity_type' => 'prediction_uploaded']);
        $this->assertDatabaseMissing('user_activities', ['activity_type' => 'training_job_created']);
        $this->assertFalse(Schema::hasTable('training_jobs'));
        $this->assertFalse(Schema::hasColumn('models', 'kind'));
    }

    public function test_retired_file_cleanup_preserves_prediction_uploads_news_and_evidence(): void
    {
        Storage::fake('local');
        config(['storage_guard.require_sentinel' => false]);
        Storage::put('training/weights/retired.h5', 'retired');
        Storage::put('predictions/1/kept/input/frame_001.tif', 'kept');
        Storage::put('prediction-evidence/1/kept/thumb.png', 'kept');
        Storage::put('news/kept.png', 'kept');
        $retired = 'temp/uploads/1/11111111-1111-1111-1111-111111111111';
        $kept = 'temp/uploads/1/22222222-2222-2222-2222-222222222222';
        Storage::put($retired . '.json', json_encode(['purpose' => 'training']));
        Storage::put($retired . '.part', 'retired');
        Storage::put($kept . '.json', json_encode(['purpose' => 'prediction']));
        Storage::put($kept . '.part', 'kept');

        $this->artisan('app:cleanup-retired-data')->assertSuccessful();
        Storage::assertMissing(['training/weights/retired.h5', $retired . '.json', $retired . '.part']);
        Storage::assertExists(['predictions/1/kept/input/frame_001.tif', 'prediction-evidence/1/kept/thumb.png', 'news/kept.png', $kept . '.json', $kept . '.part']);
        $this->artisan('app:cleanup-retired-data')->assertSuccessful();
    }

    public function test_retired_cleanup_refuses_missing_mounts_and_unmigrated_databases(): void
    {
        Storage::fake('local');
        Storage::put('training/weights/retired.h5', 'retired');
        config(['storage_guard.require_sentinel' => true, 'storage_guard.sentinel_file' => '.missing']);
        $this->artisan('app:cleanup-retired-data')->assertFailed();
        Storage::assertExists('training/weights/retired.h5');
        config(['storage_guard.require_sentinel' => false]);
        $this->restoreLegacySchema();
        $this->artisan('app:cleanup-retired-data')->assertFailed();
        Storage::assertExists('training/weights/retired.h5');
        (require database_path('migrations/2026_10_09_010000_remove_managed_training.php'))->up();
    }

    private function restoreLegacySchema(): void
    {
        foreach (['2026_08_16_100001_create_training_tables.php', '2026_08_18_000001_training_belongs_to_the_researcher.php', '2026_08_23_100001_create_training_samples_table.php'] as $file) {
            (require database_path('migrations/' . $file))->up();
        }
    }

    private function account(string $role): User
    {
        return User::create(['name' => $role, 'email' => $role . '@prediction-only.test', 'password' => bcrypt('test-password'), 'role' => $role, 'is_active' => true]);
    }
}
