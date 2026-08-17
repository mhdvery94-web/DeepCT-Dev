<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model as EloquentModel;

class Model extends EloquentModel
{
    protected $fillable = [
        'name',
        'version',
        // 'inference' or 'trainer'. One registry, two purposes: a trainer
        // endpoint is registered, switched on and health-checked exactly like
        // an inference endpoint, so it would be a second table with the same
        // columns and the same probe behind it.
        'kind',
        'endpoint_url',
        'file_path',
        'status',
        'last_health_check',
        'max_concurrent_jobs',
        'current_jobs_count',
        'accuracy',
        'description',
        'total_predictions',
        'deployed_at',
        'health_check_error',
        'is_active',
    ];

    protected $casts = [
        'accuracy' => 'decimal:2',
        'is_active' => 'boolean',
        'last_health_check' => 'datetime',
        'deployed_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Get analysis records using this model
     */
    public function analysisRecords()
    {
        return $this->hasMany(AnalysisRecord::class);
    }

    /**
     * Endpoints that answer `POST /predict`.
     *
     * Every query that existed before this column did means this one. A trainer
     * appearing in the model picker on the upload screen would offer a
     * researcher an endpoint that cannot interpolate anything.
     */
    public function scopeInference($query)
    {
        return $query->where('kind', 'inference');
    }

    /** Endpoints that answer `POST /train`. */
    public function scopeTrainers($query)
    {
        return $query->where('kind', 'trainer');
    }

    public function isTrainer(): bool
    {
        return $this->kind === 'trainer';
    }
}
