<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A video beside the photo, so a post can carry a clip of the activity.
 *
 * Mirrors the image pair, plus a size. 4 MB does not need announcing; 50 MB
 * does — the number is shown next to the play button so someone on a slow
 * connection knows what they are about to start.
 *
 * Both are optional and independent: a post may have neither, either, or both.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('news_posts', function (Blueprint $table) {
            $table->string('video_path')->nullable()->after('image_mime');
            $table->string('video_mime', 60)->nullable()->after('video_path');
            $table->unsignedBigInteger('video_size_bytes')->nullable()->after('video_mime');
        });
    }

    public function down(): void
    {
        Schema::table('news_posts', function (Blueprint $table) {
            $table->dropColumn(['video_path', 'video_mime', 'video_size_bytes']);
        });
    }
};
