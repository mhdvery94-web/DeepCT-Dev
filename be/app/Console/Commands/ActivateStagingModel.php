<?php

namespace App\Console\Commands;

use App\Models\Model;
use App\Models\ModelUpload;
use App\Services\ModelUploads;
use Illuminate\Console\Command;

/**
 * Recover the operator path for a model uploaded by an older staging account.
 *
 * The HTTP control plane intentionally scopes upload sessions to their owner.
 * A retained session can therefore outlive the account an operator currently
 * uses. This command does not change ownership or expose a control token; it
 * verifies the immutable tuple and asks the existing authenticated service to
 * perform the same revisioned activation used by the dashboard.
 */
class ActivateStagingModel extends Command
{
    protected $signature = 'models:activate-staging
        {model_id : Immutable managed model identifier}
        {version : Semantic model version}
        {--apply : Perform activation after the audit passes}';

    protected $description = 'Audit or explicitly activate one retained model upload in staging';

    public function handle(ModelUploads $uploads): int
    {
        if (! app()->environment('staging')) {
            $this->error('This operator command is restricted to APP_ENV=staging.');

            return self::FAILURE;
        }

        $modelId = (string) $this->argument('model_id');
        $version = (string) $this->argument('version');
        if (! preg_match('/^[a-z0-9]+(?:-[a-z0-9]+)*$/D', $modelId)
            || ! preg_match('/^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$/D', $version)) {
            $this->error('Invalid immutable model identity.');

            return self::INVALID;
        }

        $model = Model::where('managed_model_id', $modelId)
            ->where('version', $version)->first();
        $upload = ModelUpload::where('manifest->model_id', $modelId)
            ->where('manifest->version', $version)->latest('id')->first();
        if (! $model || ! $upload || ! $upload->tuf_id) {
            $this->error('The catalog row and retained upload session must both exist.');

            return self::FAILURE;
        }
        if (! hash_equals((string) $model->weight_sha256, (string) ($upload->manifest['sha256'] ?? ''))) {
            $this->error('Catalog and retained upload checksums do not match.');

            return self::FAILURE;
        }

        $remote = $uploads->request('GET', '/management/uploads/'.$upload->tuf_id);
        if (($remote['manifest'] ?? null) != $upload->manifest
            || ! ($remote['published'] ?? false)
            || ! in_array($remote['state'] ?? null, ['ready_for_activate', 'active'], true)) {
            $this->error('The worker session is not an immutable published activation candidate.');

            return self::FAILURE;
        }

        $this->line("Verified {$modelId} {$version}: worker state {$remote['state']}.");
        if (! $this->option('apply')) {
            $this->info('Audit passed; no availability state was changed.');

            return self::SUCCESS;
        }

        if (($remote['state'] ?? null) !== 'active') {
            $uploads->action($upload, 'activate');
        } else {
            $uploads->synchronize();
        }

        $model->refresh();
        if (! $model->is_active || ! $model->worker_active || $model->availability_transition) {
            $this->error('Activation did not reconcile to an available model.');

            return self::FAILURE;
        }

        $this->info("Activated {$modelId} {$version} for staging prediction UAT.");

        return self::SUCCESS;
    }
}
