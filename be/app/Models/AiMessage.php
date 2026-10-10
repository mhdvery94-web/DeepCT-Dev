<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AiMessage extends Model
{
    protected $guarded = ['id'];

    public function toPublicArray(): array
    {
        return ['id' => $this->id, 'role' => $this->role, 'content' => $this->content,
            'created_at' => $this->created_at->toIso8601String()];
    }
}
