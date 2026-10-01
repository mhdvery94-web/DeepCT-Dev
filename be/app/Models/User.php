<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Storage;
use App\Models\AnalysisRecord;
use App\Services\ResultEvidence;
use RuntimeException;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable, HasApiTokens;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'phone',
        'email',
        'email_verified_at',
        'password',
        'must_change_password',
        'role',
        'avatar_path',
        'avatar_mime',
        'is_active',
        'last_login_at',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        // Where the photo sits on disk is nobody's business; clients get
        // `avatar_url` instead.
        'avatar_path',
        'avatar_mime',
    ];

    /**
     * Appended so every endpoint that returns a user carries the photo,
     * including the ones that just hand back `$query->paginate()->items()`.
     */
    protected $appends = ['avatar_url'];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'must_change_password' => 'boolean',
            'is_active' => 'boolean',
            'last_login_at' => 'datetime',
        ];
    }

    /**
     * Clean up what nothing else would.
     *
     * `notifications` and `personal_access_tokens` are polymorphic, so neither
     * carries a foreign key back to this row and deleting an account leaves
     * both behind forever — unreadable, uncollectable, and in the token's case
     * a credential nobody owns. The avatar is a file rather than a row, so it
     * has no cascade to inherit either.
     */
    protected static function booted(): void
    {
        static::deleting(function (self $user) {
            // The database cascades prediction rows, but it cannot cascade
            // their files. Remove those before the rows disappear; a failed
            // storage operation leaves the account and its records available
            // for a later retry.
            $directories = [
                "predictions/{$user->id}",
                "temp/uploads/{$user->id}",
                "temp/downloads/{$user->id}",
            ];

            foreach (AnalysisRecord::where('user_id', $user->id)->get() as $record) {
                $directories[] = ResultEvidence::directoryFor($record);
            }

            foreach ($directories as $directory) {
                if (Storage::directoryExists($directory)
                    && !Storage::deleteDirectory($directory)) {
                    throw new RuntimeException("Could not remove {$directory} while deleting the account.");
                }
            }

            $user->notifications()->delete();
            $user->tokens()->delete();

            if ($user->avatar_path && Storage::exists($user->avatar_path)) {
                Storage::delete($user->avatar_path);
            }
        });
    }

    /** Accepted profile-photo types. Nothing here can re-encode an upload. */
    public const AVATAR_MIMES = ['image/jpeg', 'image/png', 'image/webp'];

    /** 2 MB. A 96px circle does not need more. */
    public const MAX_AVATAR_BYTES = 2 * 1024 * 1024;

    public function hasAvatar(): bool
    {
        return $this->avatar_path !== null;
    }

    /**
     * The URL the client should load, relative to the API root.
     *
     * Null when there is no photo, which is what tells the client to draw the
     * initials frame instead.
     */
    public function avatarUrl(): ?string
    {
        return $this->hasAvatar() ? "/users/{$this->id}/avatar" : null;
    }

    /** Backs the appended `avatar_url` attribute. */
    public function getAvatarUrlAttribute(): ?string
    {
        return $this->avatarUrl();
    }

    /**
     * The fields every endpoint agrees on when it returns a user.
     *
     * Collected here because five controllers were each building their own
     * array, and `avatar_url` had to appear in all of them.
     */
    public function toPublicArray(): array
    {
        return [
            'id' => $this->id,
            'phone' => $this->phone,
            'name' => $this->name,
            'email' => $this->email,
            'role' => $this->role,
            'is_active' => $this->is_active,
            'avatar_url' => $this->avatarUrl(),
            // The client blocks the console behind a password change while
            // this is true, so it has to travel with every user payload the
            // app authenticates from -- login and `/user` both.
            'must_change_password' => (bool) $this->must_change_password,
        ];
    }
}
