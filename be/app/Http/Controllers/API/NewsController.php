<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\NewsPost;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Research news for the landing page.
 *
 * Two audiences: the public sees published posts only, an administrator sees
 * and edits everything. The split is enforced by which method the route
 * reaches, not by a flag in the payload.
 */
class NewsController extends Controller
{
    /** Where uploaded photos live on the local disk. */
    private const IMAGE_DIR = 'news';

    private function serialise(NewsPost $post, bool $forAdmin = false): array
    {
        $data = [
            'id' => $post->id,
            'title' => $post->title,
            'summary' => $post->summary,
            'body' => $post->body,
            'has_image' => $post->hasImage(),
            // Relative to the API root; the client prefixes its base URL.
            'image_url' => $post->hasImage() ? "/news/{$post->id}/image" : null,
            'published_at' => $post->published_at?->toIso8601String(),
            'sort_order' => $post->sort_order,
        ];

        if ($forAdmin) {
            $data['is_published'] = $post->is_published;
            $data['created_at'] = $post->created_at?->toIso8601String();
            $data['updated_at'] = $post->updated_at?->toIso8601String();
            $data['author'] = $post->relationLoaded('author') && $post->author
                ? $post->author->name
                : null;
        }

        return $data;
    }

    // ------------------------------------------------------------- public

    /**
     * GET /api/news — published posts, in slideshow order.
     *
     * Not paginated: the landing page shows all of them in a carousel, and a
     * research group publishing enough news to need pages is a problem worth
     * having first.
     */
    public function index(Request $request)
    {
        $limit = max(1, min((int) $request->input('limit', 20), 50));

        $posts = NewsPost::published()->inSlideOrder()->limit($limit)->get();

        return response()->json([
            'success' => true,
            'data' => $posts->map(fn($p) => $this->serialise($p))->all(),
        ]);
    }

    /**
     * GET /api/news/{id}/image — the photo itself.
     *
     * Public for a published post. An unpublished one is only served to an
     * administrator, so a draft cannot be found by guessing ids — the route
     * carries no auth middleware, but the token is still resolved when one is
     * sent, which is what makes the admin preview work.
     */
    public function image(Request $request, $id)
    {
        $post = NewsPost::findOrFail($id);

        if (!$post->is_published) {
            $user = $request->user() ?? auth('sanctum')->user();

            if (!$user || $user->role !== 'admin') {
                abort(404);
            }
        }

        if (!$post->hasImage() || !Storage::exists($post->image_path)) {
            abort(404);
        }

        return response()->file(Storage::path($post->image_path), [
            'Content-Type' => $post->image_mime ?? 'application/octet-stream',
            // Safe to cache: replacing a photo writes a new filename, so the
            // URL for a *changed* image is never the same one.
            'Cache-Control' => 'public, max-age=3600',
        ]);
    }

    // -------------------------------------------------------------- admin

    /** GET /api/admin/news — everything, drafts included. */
    public function adminIndex(Request $request)
    {
        $perPage = max(1, min((int) $request->input('per_page', 15), 100));

        $query = NewsPost::with('author:id,name');

        if ($request->filled('status')) {
            $query->where('is_published', $request->input('status') === 'published');
        }

        if ($search = $request->input('search')) {
            $query->where('title', 'like', "%{$search}%");
        }

        $posts = $query->inSlideOrder()->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => collect($posts->items())
                ->map(fn($p) => $this->serialise($p, forAdmin: true))
                ->all(),
            'pagination' => [
                'total' => $posts->total(),
                'per_page' => $posts->perPage(),
                'current_page' => $posts->currentPage(),
                'last_page' => $posts->lastPage(),
                'from' => $posts->firstItem(),
                'to' => $posts->lastItem(),
            ],
            'meta' => [
                'published_count' => NewsPost::published()->count(),
                'draft_count' => NewsPost::where('is_published', false)->count(),
            ],
        ]);
    }

    /** POST /api/admin/news — multipart, because it may carry a photo. */
    public function store(Request $request)
    {
        $validated = $this->validatePayload($request, creating: true);

        $post = new NewsPost([
            'title' => $validated['title'],
            'summary' => $validated['summary'],
            'body' => $validated['body'] ?? null,
            'sort_order' => (int) ($validated['sort_order'] ?? 0),
            'created_by' => $request->user()->id,
        ]);

        $this->applyPublishFlag($post, $request);
        $this->storeImage($post, $request);

        $post->save();

        return response()->json([
            'success' => true,
            'message' => 'Post created.',
            'data' => $this->serialise($post->fresh()->load('author'), forAdmin: true),
        ], 201);
    }

    /** GET /api/admin/news/{id} */
    public function show($id)
    {
        $post = NewsPost::with('author:id,name')->findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $this->serialise($post, forAdmin: true),
        ]);
    }

    /**
     * POST /api/admin/news/{id} — update.
     *
     * POST rather than PUT on purpose: a photo arrives as multipart, and PHP
     * does not populate `$_FILES` for PUT. `_method=PUT` would work too, but
     * only by round-tripping through the same POST.
     */
    public function update(Request $request, $id)
    {
        $post = NewsPost::findOrFail($id);
        $validated = $this->validatePayload($request, creating: false);

        foreach (['title', 'summary', 'body'] as $field) {
            if (array_key_exists($field, $validated)) {
                $post->{$field} = $validated[$field];
            }
        }

        if (array_key_exists('sort_order', $validated)) {
            $post->sort_order = (int) $validated['sort_order'];
        }

        $this->applyPublishFlag($post, $request);
        $this->storeImage($post, $request);

        if ($request->boolean('remove_image')) {
            $this->deleteImage($post);
            $post->image_path = null;
            $post->image_mime = null;
        }

        $post->save();

        return response()->json([
            'success' => true,
            'message' => 'Post updated.',
            'data' => $this->serialise($post->fresh()->load('author'), forAdmin: true),
        ]);
    }

    /** PATCH /api/admin/news/{id}/toggle — the on/off switch. */
    public function toggle($id)
    {
        $post = NewsPost::findOrFail($id);

        $post->is_published = !$post->is_published;
        // Recorded on first publish only, so re-publishing an old post does
        // not push it to the front of the slideshow.
        $post->published_at ??= $post->is_published ? now() : null;
        $post->save();

        return response()->json([
            'success' => true,
            'message' => $post->is_published ? 'Post published.' : 'Post hidden.',
            'data' => $this->serialise($post->fresh()->load('author'), forAdmin: true),
        ]);
    }

    /** DELETE /api/admin/news/{id} */
    public function destroy($id)
    {
        $post = NewsPost::findOrFail($id);

        $this->deleteImage($post);
        $post->delete();

        return response()->json(['success' => true, 'message' => 'Post deleted.']);
    }

    // ------------------------------------------------------------ helpers

    private function validatePayload(Request $request, bool $creating): array
    {
        return $request->validate([
            'title' => ($creating ? 'required' : 'sometimes|required') . '|string|max:200',
            'summary' => ($creating ? 'required' : 'sometimes|required') . '|string|max:500',
            'body' => 'nullable|string|max:20000',
            'sort_order' => 'nullable|integer|min:0|max:9999',
            'is_published' => 'nullable|boolean',
            'remove_image' => 'nullable|boolean',
            'image' => [
                'nullable',
                'file',
                'max:' . (NewsPost::MAX_IMAGE_BYTES / 1024),
                'mimetypes:' . implode(',', NewsPost::IMAGE_MIMES),
            ],
        ]);
    }

    private function applyPublishFlag(NewsPost $post, Request $request): void
    {
        if (!$request->has('is_published')) {
            return;
        }

        $post->is_published = $request->boolean('is_published');
        $post->published_at ??= $post->is_published ? now() : null;
    }

    /**
     * Save an uploaded photo, replacing any previous one.
     *
     * The file is stored byte-for-byte: this machine has neither GD nor
     * Imagick, so there is nothing to resize or re-encode with. That is why
     * the size limit and the mime whitelist are the only defence, and why
     * `mimetypes:` is used rather than `mimes:` — it reads the file's actual
     * type instead of trusting the extension.
     */
    private function storeImage(NewsPost $post, Request $request): void
    {
        if (!$request->hasFile('image')) {
            return;
        }

        $this->deleteImage($post);

        $file = $request->file('image');
        $path = $file->store(self::IMAGE_DIR);

        $post->image_path = $path;
        $post->image_mime = $file->getMimeType();
    }

    private function deleteImage(NewsPost $post): void
    {
        if ($post->image_path && Storage::exists($post->image_path)) {
            Storage::delete($post->image_path);
        }
    }
}
