<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ModelUpload extends Model
{
    protected $fillable = ['user_id', 'tuf_id', 'manifest', 'state', 'intent_id', 'creation_key', 'availability_revision'];

    protected $casts = ['manifest' => 'array', 'availability_revision' => 'integer'];
}
