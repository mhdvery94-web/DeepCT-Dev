<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model as EloquentModel;

class Model extends EloquentModel
{
    protected $fillable = [
        'name',
        'slug',
        'version',
        // 'inference' or 'trainer'. One registry, two purposes: a trainer
        // endpoint is registered, switched on and health-checked exactly like
        // an inference endpoint, so it would be a second table with the same
        // columns and the same probe behind it.
        'kind',
        'base_url',
        'endpoint',
        'full_endpoint_url',
        'endpoint_url',
        // Shared secret sent to the worker as `Authorization: Bearer`, and
        // whether that worker's certificate is checked. See the migration
        // `add_worker_auth_to_models` for why `verify_tls` defaults to false.
        'auth_token',
        'verify_tls',
        'file_path',
        'model_file',
        'worker_active',
        'status',
        'last_health_check',
        'synced_at',
        'current_jobs_count',
        'accuracy',
        'description',
        'total_predictions',
        'deployed_at',
        'health_check_error',
        'health_check_reason',
        'is_active',
    ];

    /**
     * The worker secret never leaves the server.
     *
     * `$hidden` covers every `toArray()` and `toJson()`, which is how models
     * reach the client from half a dozen places — the registry list, the
     * upload screen's picker, an activity row's metadata. Missing one of
     * those would publish the credential to every signed-in researcher.
     */
    protected $hidden = ['auth_token'];

    /**
     * Whether a secret is set, which is all anyone needs to be told.
     *
     * An administrator has to know if a worker is protected; nobody has to
     * read the key back to know that. Replacing it is the only way to change
     * it, which is also how a credential should behave.
     */
    protected $appends = ['has_auth_token'];

    public function getHasAuthTokenAttribute(): bool
    {
        // The raw attribute, not the accessor: decrypting on every
        // serialisation of every model in the registry would be work done for
        // an answer that is only ever "yes" or "no".
        return filled($this->attributes['auth_token'] ?? null);
    }

    protected $casts = [
        // Encrypted at rest: a database dump should not hand over the key to
        // someone else's GPU.
        'auth_token' => 'encrypted',
        'verify_tls' => 'boolean',
        'accuracy' => 'decimal:2',
        'is_active' => 'boolean',
        'worker_active' => 'boolean',
        'last_health_check' => 'datetime',
        'synced_at' => 'datetime',
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

    /** The URL used for inference, with a fallback for pre-migration rows. */
    public function predictionUrl(): ?string
    {
        return $this->full_endpoint_url ?: $this->endpoint_url;
    }

    /** Whether this row came from a multi-model server catalogue. */
    public function usesModelCatalog(): bool
    {
        return $this->kind === 'inference'
            && filled($this->base_url)
            && filled($this->slug);
    }

    public function catalogUrl(): ?string
    {
        return filled($this->base_url)
            ? rtrim($this->base_url, '/') . '/models'
            : null;
    }
}
