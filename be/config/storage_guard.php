<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Room to accept an upload
    |--------------------------------------------------------------------------
    |
    | One archive costs disk three times over before it is done with: the
    | frames extracted from it, the frames the model generates from those, and
    | the temporary archive built to hand the results back. Generated frames
    | routinely outnumber uploaded ones — two boundaries around a gap of five
    | produce four — so three is a floor rather than a margin.
    |
    */
    'headroom_multiplier' => (float) env('STORAGE_HEADROOM_MULTIPLIER', 3.0),

    /*
    | An absolute floor, whatever the upload is. A machine that accepts work
    | until the disk reads zero does not merely stop accepting work: MySQL
    | cannot write, the queue cannot record a failure, and the logs that would
    | explain any of it cannot be written either.
    |
    | Two gigabytes is aimed at a Raspberry Pi, where root and the database
    | share whatever is left.
    */
    'minimum_free_bytes' => (int) env('STORAGE_MINIMUM_FREE_BYTES', 2 * 1024 * 1024 * 1024),

    /*
    |--------------------------------------------------------------------------
    | Proof that the storage really is the storage
    |--------------------------------------------------------------------------
    |
    | When results live on a NAS, the failure that matters is not the NAS being
    | full — it is the NAS being *absent*. An unmounted share leaves a perfectly
    | ordinary empty directory behind, and `Storage::put()` writes into it
    | happily, filling the host's own disk with frames nobody will find again.
    |
    | So the mount carries a file that only exists there. Missing means not
    | mounted, and not mounted means refuse rather than write somewhere wrong.
    |
    | **Off by default.** A single-disk install has nothing to be absent, and
    | turning this on without creating the sentinel first would refuse every
    | upload. Create it with `php artisan storage:mark`, then switch this on.
    |
    */
    'require_sentinel' => (bool) env('STORAGE_REQUIRE_SENTINEL', false),

    'sentinel_file' => env('STORAGE_SENTINEL_FILE', '.storage-mounted'),

];
