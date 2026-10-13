<?php

namespace App\Services;

use App\Models\AnalysisRecord;
use App\Models\Model;
use Illuminate\Support\Facades\DB;

/** All admissions and availability mutations lock the selected registry row. */
class ModelAdmission
{
    public function available(Model $model): void
    {
        abort_unless(! $model->availability_transition && $model->is_active && (! $model->managed_model_id || $model->worker_active), 422, 'Selected model version is inactive or reconciling.');
        abort_if($model->status === 'offline', 503, 'Selected model version is offline.');
    }

    public function assertIdle(Model $model): void
    {
        abort_if($model->current_jobs_count > 0 || $model->analysisRecords()->whereIn('status', ['pending', 'processing'])->exists(),
            409, 'This version has pending or processing jobs.');
    }

    public function snapshot(Model $model): array
    {
        $snapshot = ['id' => $model->id, 'name' => mb_substr($model->name, 0, 120),
            'slug' => $model->slug === null ? null : mb_substr($model->slug, 0, 120),
            'version' => mb_substr($model->version, 0, 64),
            'provenance' => $model->managed_model_id ? 'managed_manifest_sha256' : 'legacy_registry_metadata'];
        if ($model->managed_model_id) {
            $snapshot += ['model_id' => $model->managed_model_id, 'sha256' => $model->weight_sha256];
        }

        return $snapshot;
    }

    public function start(AnalysisRecord $record): AnalysisRecord
    {
        return DB::transaction(function () use ($record) {
            $model = Model::whereKey($record->model_id)->lockForUpdate()->firstOrFail();
            $this->available($model);
            $record = AnalysisRecord::whereKey($record->id)->lockForUpdate()->firstOrFail();
            abort_unless($record->status === 'uploaded', 409, 'This analysis has already been started.');
            $record->update(['status' => 'pending', 'model_snapshot' => $this->snapshot($model)]);

            return $record;
        });
    }

    public function createPending(Model $model, array $attributes): AnalysisRecord
    {
        return DB::transaction(function () use ($model, $attributes) {
            $model = Model::whereKey($model->id)->lockForUpdate()->firstOrFail();
            $this->available($model);

            return AnalysisRecord::create($attributes + ['model_snapshot' => $this->snapshot($model)]);
        });
    }

    public function toggle(Model $model): Model
    {
        return DB::transaction(function () use ($model) {
            $model = Model::whereKey($model->id)->lockForUpdate()->firstOrFail();
            abort_if($model->managed_model_id, 409, 'Use managed activation controls.');
            $this->assertIdle($model);
            $model->update(['is_active' => ! $model->is_active]);

            return $model;
        });
    }

    public function delete(Model $model): void
    {
        DB::transaction(function () use ($model) {
            $model = Model::whereKey($model->id)->lockForUpdate()->firstOrFail();
            abort_if($model->managed_model_id, 409, 'Managed versions are retained.');
            $this->assertIdle($model);
            $model->delete();
        });
    }
}
