<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * Split a model's server address from its prediction path.
 *
 * `endpoint_url` remains in place for backwards compatibility with existing
 * deployments and clients. New code writes it together with
 * `full_endpoint_url`; old rows are backfilled so a rolling deployment can run
 * either version while Octane and queue workers restart.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->string('slug')->nullable()->after('name');
            $table->string('base_url', 500)->nullable()->after('kind');
            $table->string('endpoint', 500)->nullable()->after('base_url');
            $table->string('full_endpoint_url', 1000)->nullable()->after('endpoint');
            $table->string('model_file', 500)->nullable()->after('file_path');
            $table->boolean('worker_active')->default(false)->after('model_file');
            $table->timestamp('synced_at')->nullable()->after('last_health_check');
        });

        $usedSlugs = [];

        DB::table('models')->orderBy('id')->get()->each(function ($model) use (&$usedSlugs) {
            $baseSlug = Str::slug((string) $model->name) ?: "model-{$model->id}";
            $slug = $baseSlug;

            if (isset($usedSlugs[$slug])) {
                $slug = "{$baseSlug}-{$model->id}";
            }
            $usedSlugs[$slug] = true;

            $url = (string) ($model->endpoint_url ?? '');
            $parts = $url !== '' ? parse_url($url) : false;
            $baseUrl = null;
            $endpoint = null;

            if (is_array($parts) && ! empty($parts['host'])) {
                $scheme = $parts['scheme'] ?? 'https';
                $port = isset($parts['port']) ? ':' . $parts['port'] : '';
                $baseUrl = "{$scheme}://{$parts['host']}{$port}";
                $endpoint = $parts['path'] ?? '/';
                if (isset($parts['query'])) {
                    $endpoint .= '?' . $parts['query'];
                }
            }

            DB::table('models')->where('id', $model->id)->update([
                'slug' => $slug,
                'base_url' => $baseUrl,
                'endpoint' => $endpoint,
                'full_endpoint_url' => $url !== '' ? $url : null,
                'model_file' => $model->file_path ? basename((string) $model->file_path) : null,
            ]);
        });

        Schema::table('models', function (Blueprint $table) {
            $table->unique('slug');
            $table->index(['base_url', 'kind']);
        });
    }

    public function down(): void
    {
        Schema::table('models', function (Blueprint $table) {
            $table->dropIndex(['base_url', 'kind']);
            $table->dropUnique(['slug']);
            $table->dropColumn([
                'slug',
                'base_url',
                'endpoint',
                'full_endpoint_url',
                'model_file',
                'worker_active',
                'synced_at',
            ]);
        });
    }
};
