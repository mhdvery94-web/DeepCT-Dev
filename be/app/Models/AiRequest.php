<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

class AiRequest extends Model
{
    public const ACTIVE = ['queued', 'processing'];

    protected $guarded = ['id'];

    protected $casts = ['requested_analysis_record_id' => 'integer', 'sources' => 'array', 'metrics' => 'array', 'started_at' => 'datetime', 'finished_at' => 'datetime'];

    protected static function booted(): void
    {
        static::updating(function (self $request) {
            if ($request->isDirty('requested_analysis_record_id')) {
                throw new LogicException('The admitted analysis selection is immutable.');
            }
        });
    }

    public function assistantMessage(): BelongsTo
    {
        return $this->belongsTo(AiMessage::class, 'assistant_message_id');
    }

    public function toPublicArray(): array
    {
        $sources = array_map(function (array $source) {
            $source['metrics'] = (object) ($source['metrics'] ?? []);
            $source['validation_provenance'] = (object) ($source['validation_provenance'] ?? []);
            $source['frame_provenance'] = array_map(fn (array $row) => (object) $row, $source['frame_provenance'] ?? []);

            return $source;
        }, $this->sources ?? []);

        return [
            'id' => $this->id, 'conversation_id' => $this->ai_conversation_id,
            'user_message_id' => $this->user_message_id, 'status' => $this->status,
            'analysis_record_id' => $this->requested_analysis_record_id,
            'model' => $this->model, 'prompt_version' => $this->prompt_version,
            'error_code' => $this->error_code, 'experimental' => true,
            'assistant_message' => $this->assistantMessage?->toPublicArray(),
            'sources' => $sources, 'metrics' => $this->metrics === null ? null : (object) $this->metrics,
            'created_at' => $this->created_at->toIso8601String(),
            'started_at' => $this->started_at?->toIso8601String(),
            'finished_at' => $this->finished_at?->toIso8601String(),
        ];
    }
}
