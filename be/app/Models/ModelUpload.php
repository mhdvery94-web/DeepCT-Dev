<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ModelUpload extends Model
{
    protected $fillable = ['user_id', 'tuf_id', 'manifest', 'state'];

    protected $casts = ['manifest' => 'array'];
}
