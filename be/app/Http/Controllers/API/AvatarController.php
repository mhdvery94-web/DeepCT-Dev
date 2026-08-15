<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserActivity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Profile photos.
 *
 * A researcher manages their own; an administrator may set or clear anyone's,
 * because someone has to be able to remove an inappropriate photo from an
 * account that is not theirs.
 */
class AvatarController extends Controller
{
    private const DIR = 'avatars';

    /**
     * GET /api/users/{id}/avatar
     *
     * Authenticated, not public: profile photos show up beside activity logs
     * and in the user list, so any signed-in account needs to load them — but
     * an anonymous visitor enumerating ids should not be able to harvest
     * pictures of the research staff.
     */
    public function show($id)
    {
        $user = User::findOrFail($id);

        if (!$user->hasAvatar() || !Storage::exists($user->avatar_path)) {
            // 404 rather than a default image: the client draws the initials
            // frame itself, and a server-side placeholder would be a second
            // opinion about what "no photo" looks like.
            abort(404);
        }

        return response()->file(Storage::path($user->avatar_path), [
            'Content-Type' => $user->avatar_mime ?? 'application/octet-stream',
            // A new upload writes a new filename, so a cached URL is never a
            // stale picture — it is simply no longer referenced.
            'Cache-Control' => 'private, max-age=3600',
        ]);
    }

    /** POST /api/me/avatar — the caller's own photo. */
    public function updateOwn(Request $request)
    {
        return $this->store($request, $request->user(), self: true);
    }

    /** DELETE /api/me/avatar */
    public function destroyOwn(Request $request)
    {
        return $this->clear($request->user());
    }

    /** POST /api/admin/users/{id}/avatar */
    public function updateFor(Request $request, $id)
    {
        return $this->store($request, User::findOrFail($id), self: false);
    }

    /** DELETE /api/admin/users/{id}/avatar */
    public function destroyFor($id)
    {
        return $this->clear(User::findOrFail($id));
    }

    // ------------------------------------------------------------ internals

    private function store(Request $request, User $user, bool $self)
    {
        $request->validate([
            'avatar' => [
                'required',
                'file',
                'max:' . (User::MAX_AVATAR_BYTES / 1024),
                // Reads the file's bytes rather than trusting its extension.
                // There is no GD or Imagick here to re-encode a bad upload
                // into something safe, so the check has to be the real one.
                'mimetypes:' . implode(',', User::AVATAR_MIMES),
            ],
        ]);

        $this->deleteFile($user);

        $file = $request->file('avatar');
        $user->update([
            'avatar_path' => $file->store(self::DIR),
            'avatar_mime' => $file->getMimeType(),
        ]);

        if ($self) {
            UserActivity::create([
                'user_id' => $user->id,
                'activity_type' => 'profile_updated',
                'description' => 'Updated profile photo',
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Photo updated.',
            'data' => $user->fresh()->toPublicArray(),
        ]);
    }

    private function clear(User $user)
    {
        $this->deleteFile($user);
        $user->update(['avatar_path' => null, 'avatar_mime' => null]);

        return response()->json([
            'success' => true,
            'message' => 'Photo removed.',
            'data' => $user->fresh()->toPublicArray(),
        ]);
    }

    private function deleteFile(User $user): void
    {
        if ($user->avatar_path && Storage::exists($user->avatar_path)) {
            Storage::delete($user->avatar_path);
        }
    }
}
