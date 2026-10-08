<?php

namespace Tests\Feature;

use App\Models\NewsPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PublishedArticleTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_article_includes_the_entire_body(): void
    {
        $author = User::create(['name' => 'Editor', 'email' => 'editor@article.test', 'password' => bcrypt('password'), 'role' => 'admin', 'is_active' => true]);
        $post = NewsPost::create(['title' => 'CT research', 'summary' => 'Summary', 'body' => "First paragraph.\n\nComplete research details.", 'is_published' => true, 'published_at' => now(), 'created_by' => $author->id]);
        $this->getJson("/api/news/{$post->id}")->assertOk()->assertJsonPath('data.body', $post->body);
        $post->update(['is_published' => false]);
        $this->apiAs(null)->getJson("/api/news/{$post->id}")->assertNotFound();
        $this->apiAs($author->createToken('test')->plainTextToken)->getJson("/api/news/{$post->id}")->assertNotFound();
    }
}
