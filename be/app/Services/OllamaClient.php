<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

class OllamaClient
{
    public function generate(string $model, array $messages): array
    {
        $client = Http::acceptJson()->connectTimeout(10)->timeout(config('ai.http_timeout'));
        if (config('ai.token')) {
            $client = $client->withToken(config('ai.token'));
        }
        try {
            $payload = [
                'model' => $model, 'stream' => false, 'messages' => $messages, 'keep_alive' => 0,
                'options' => ['num_ctx' => config('ai.context_tokens'), 'num_predict' => config('ai.output_tokens'),
                    'temperature' => config('ai.temperature'), 'num_thread' => config('ai.threads')],
            ];
            if (config('ai.metadata_mode')) {
                $payload['think'] = false;
                $payload['format'] = AiGroundedReply::SCHEMA;
            }
            $response = $client->post(rtrim(config('ai.base_url'), '/').'/api/chat', $payload);
        } catch (ConnectionException) {
            throw new AiProviderException('provider_timeout');
        }
        if (! $response->successful()) {
            if (config('ai.gateway')) {
                $code = $response->json('error_code');
                if ($code === 'generation_busy' && in_array($response->status(), [409, 503], true)) {
                    throw new AiProviderException('generation_busy');
                }
                if ($code === 'provider_timeout' && $response->status() === 504) {
                    throw new AiProviderException('provider_timeout');
                }
            }
            throw new AiProviderException('provider_unavailable');
        }
        $body = $response->json();
        if (! is_array($body) || ($body['done'] ?? null) !== true
            || ($body['done_reason'] ?? null) !== 'stop'
            || ! is_string($body['message']['content'] ?? null)) {
            throw new AiProviderException('invalid_output');
        }
        $content = $body['message']['content'];
        // Only a single complete leading reasoning block is accepted. No raw
        // output is logged, even when malformed or reasoning-only.
        $thinkingTags = preg_match_all('/<\/?think/i', $content);
        if ($thinkingTags > 0) {
            // Validate every tag before stripping so a nested opening cannot
            // hide inside the removed block and expose unfinished reasoning.
            if ($thinkingTags !== 2 || ! preg_match('/\A\s*<think>.*?<\/think>\s*(.*)\z/su', $content, $match)) {
                throw new AiProviderException('invalid_output');
            }
            $content = $match[1];
        }
        $answer = trim($content);
        if ($answer === '' || mb_strlen($answer) > 12000) {
            throw new AiProviderException('invalid_output');
        }
        $metrics = [];
        foreach (['prompt_eval_count', 'eval_count', 'total_duration', 'load_duration', 'prompt_eval_duration', 'eval_duration'] as $key) {
            if (isset($body[$key]) && is_int($body[$key]) && $body[$key] >= 0) {
                $metrics[$key] = $body[$key];
            }
        }

        return ['answer' => $answer, 'metrics' => $metrics];
    }
}
