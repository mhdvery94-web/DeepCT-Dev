<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AiConversation extends Model
{
    protected $guarded = ['id'];

    public function messages(): HasMany
    {
        return $this->hasMany(AiMessage::class);
    }

    public function requests(): HasMany
    {
        return $this->hasMany(AiRequest::class);
    }

    public function toPublicArray(): array
    {
        return ['id' => $this->id, 'title' => $this->title,
            'created_at' => $this->created_at->toIso8601String(), 'updated_at' => $this->updated_at->toIso8601String()];
    }
}
