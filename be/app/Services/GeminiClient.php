<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

class GeminiClient
{
    private const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta';

    public function generate(string $model, array $messages): array
    {
        $apiKey = config('ai.gemini_api_key');
        if (! is_string($apiKey) || trim($apiKey) === ''
            || ! preg_match('/\A[A-Za-z0-9._-]+\z/', $model)) {
            throw new AiProviderException('provider_configuration');
        }
        $apiKey = trim($apiKey);

        $contents = array_map(function (array $message) {
            $content = $message['content'] ?? null;
            if (! is_string($content) || ! in_array($message['role'] ?? null, ['user', 'assistant'], true)) {
                throw new AiProviderException('provider_configuration');
            }

            return [
                'role' => $message['role'] === 'assistant' ? 'model' : 'user',
                'parts' => [['text' => $content]],
            ];
        }, $messages);

        try {
            $response = Http::acceptJson()
                ->withHeaders(['x-goog-api-key' => $apiKey])
                ->connectTimeout(10)
                ->timeout(min(120, max(5, (int) config('ai.gemini_timeout'))))
                ->post(self::BASE_URL.'/models/'.$model.':generateContent', [
                    'contents' => $contents,
                    'generationConfig' => [
                        'temperature' => 0,
                        'maxOutputTokens' => min(128, max(32, (int) config('ai.output_tokens'))),
                        'responseMimeType' => 'application/json',
                        'responseJsonSchema' => AiGroundedReply::SCHEMA,
                    ],
                ]);
        } catch (ConnectionException) {
            throw new AiProviderException('provider_timeout');
        }

        if (! $response->successful()) {
            $status = $response->status();
            if (in_array($status, [408, 504], true)) {
                throw new AiProviderException('provider_timeout');
            }
            if ($status === 429) {
                throw new AiProviderException('provider_rate_limited');
            }
            if (in_array($status, [400, 401, 403, 404], true)) {
                throw new AiProviderException('provider_configuration');
            }

            throw new AiProviderException('provider_unavailable');
        }

        $body = $response->json();
        $finishReason = $body['candidates'][0]['finishReason'] ?? null;
        if (in_array($finishReason, ['SAFETY', 'BLOCKLIST', 'PROHIBITED_CONTENT', 'SPII'], true)) {
            throw new AiProviderException('provider_blocked');
        }
        $parts = $body['candidates'][0]['content']['parts'] ?? null;
        if ($finishReason !== 'STOP' || ! is_array($parts) || count($parts) !== 1
            || ! is_string($parts[0]['text'] ?? null)) {
            throw new AiProviderException('invalid_output');
        }
        $answer = trim($parts[0]['text']);
        $decoded = json_decode($answer, true);
        if ($answer === '' || mb_strlen($answer) > 12000 || ! is_array($decoded)
            || array_keys($decoded) !== ['topic']
            || ! in_array($decoded['topic'], AiGroundedReply::SCHEMA['properties']['topic']['enum'], true)) {
            throw new AiProviderException('invalid_output');
        }

        $metrics = [];
        foreach (['promptTokenCount' => 'prompt_eval_count', 'candidatesTokenCount' => 'eval_count'] as $source => $target) {
            $value = $body['usageMetadata'][$source] ?? null;
            if (is_int($value) && $value >= 0) {
                $metrics[$target] = $value;
            }
        }

        return ['answer' => $answer, 'metrics' => $metrics];
    }
}
