<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Research news shown as a slideshow on the landing page.
 *
 * An administrator writes a post, attaches a photo, and turns it on. Nothing
 * is visible to the public until `is_published` is true, so a half-finished
 * post can be saved and previewed without appearing on the site.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('news_posts', function (Blueprint $table) {
            $table->id();

            $table->string('title');

            // Shown on the slide itself. The body is the full article and is
            // optional: a photo and one line is a legitimate post.
            $table->string('summary', 500);
            $table->text('body')->nullable();

            // Stored on the local disk and streamed through the API rather
            // than published to `public/`. This machine has no `storage:link`
            // and the app is reached through ngrok, where a symlinked path is
            // one more thing to get wrong.
            $table->string('image_path')->nullable();
            $table->string('image_mime', 60)->nullable();

            $table->boolean('is_published')->default(false);
            $table->timestamp('published_at')->nullable();

            // Manual ordering for the slideshow; ties break by publish date.
            $table->integer('sort_order')->default(0);

            $table->foreignId('created_by')->nullable()
                ->constrained('users')->nullOnDelete();

            $table->timestamps();

            $table->index(['is_published', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('news_posts');
    }
};
