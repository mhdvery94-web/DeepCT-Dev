<?php

use Illuminate\Database\Migrations\Migration;

/**
 * Retained historical migration, intentionally disabled for safe upgrades.
 *
 * Models may now point at live inference deployments and prediction/activity
 * references preserve their provenance. Replaying the former catalogue purge
 * must not delete those rows, nullify references, or access retired training
 * tables. Existing installations that already ran the purge require their own
 * backup to recover lost data; this migration does not invent replacement rows.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Intentional no-op: preserve the live registry and all references.
    }

    public function down(): void
    {
        // Intentionally empty. See the class docblock.
    }
};
