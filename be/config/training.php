<?php

return [

    /*
    |---------------------------------------------------------------------------
    | Worker token
    |---------------------------------------------------------------------------
    |
    | Shared secret a GPU worker presents on every /api/training/worker/* call.
    | Empty means training workers are not configured, and those routes refuse
    | with 503 — a half-configured deployment fails closed.
    |
    | Generate one with: php artisan training:token
    |
    */
    'worker_token' => env('TRAINING_WORKER_TOKEN'),

    /*
    |---------------------------------------------------------------------------
    | Upload limits
    |---------------------------------------------------------------------------
    |
    | A hosted dataset travels through this machine, so it has to stay modest.
    | Anything larger belongs on a URL the worker fetches for itself — see the
    | note in the migration about not sending 20 GB up a home tunnel and back
    | down to Kaggle.
    |
    */
    'max_dataset_bytes' => (int) env('TRAINING_MAX_DATASET_BYTES', 512 * 1024 * 1024),

    /*
    |---------------------------------------------------------------------------
    | Checkpoint and weights limits
    |---------------------------------------------------------------------------
    |
    | The generator is ~25.6M parameters, so a float32 .h5 lands near 100 MB.
    | 400 MB leaves room for an optimiser state riding along in a checkpoint.
    |
    */
    'max_weights_bytes' => (int) env('TRAINING_MAX_WEIGHTS_BYTES', 400 * 1024 * 1024),

];
