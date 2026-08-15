<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model as EloquentModel;

class Model extends EloquentModel
{
    protected $fillable = [
        'name',
        'version',
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
}
