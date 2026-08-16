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
    | Trainer endpoint
    |---------------------------------------------------------------------------
    |
    | A URL on the GPU host that accepts a job and starts training, exactly the
    | way a model endpoint accepts a pair of frames and returns an interpolated
    | one. Optional: without it a worker can still poll /training/worker/claim.
    |
    | An administrator may override it per dispatch, and the URL used is stored
    | on the job — over months a project runs against several notebooks, and
    | "which machine trained this?" should be answerable from the row.
    |
    */
    'trainer_url' => env('TRAINING_TRAINER_URL'),

    /*
    |---------------------------------------------------------------------------
    | Callback base
    |---------------------------------------------------------------------------
    |
    | What the platform tells the trainer to report back to. Defaults to
    | APP_URL, which is right in production and wrong behind a tunnel — set it
    | explicitly when the GPU host reaches this server by a different name than
    | the browser does.
    |
    */
    'callback_url' => env('TRAINING_CALLBACK_URL', env('APP_URL')),

    /*
    |---------------------------------------------------------------------------
    | Dispatch timeout
    |---------------------------------------------------------------------------
    |
    | Seconds to wait for the trainer to *accept* a job. Deliberately short: the
    | trainer must acknowledge and train in the background. A notebook that
    | holds the request open for the length of the training run would time out
    | on any network in the world.
    |
    */
    'dispatch_timeout' => (int) env('TRAINING_DISPATCH_TIMEOUT', 30),

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
