<?php

namespace App\Services;

class AssistantProvider
{
    public function __construct(
        private readonly OllamaClient $ollama,
        private readonly GeminiClient $gemini,
    ) {}

    public function generate(string $admittedModel, array $messages): array
    {
        $provider = strtolower((string) config('ai.provider'));
        if ($provider === 'ollama') {
            return $this->withModel(
                $this->ollama->generate($admittedModel, $messages),
                $admittedModel,
            );
        }
        if (! in_array($provider, ['gemini', 'hybrid'], true) || ! config('ai.metadata_mode')) {
            throw new AiProviderException('provider_configuration');
        }

        $geminiModel = (string) config('ai.gemini_model');
        try {
            return $this->withModel($this->gemini->generate($geminiModel, $messages), $geminiModel);
        } catch (AiProviderException $exception) {
            if ($provider !== 'hybrid' || ! in_array($exception->getMessage(), [
                'provider_timeout', 'provider_rate_limited', 'provider_unavailable', 'invalid_output',
            ], true)) {
                throw $exception;
            }
        }

        $ollamaModel = (string) config('ai.ollama_model');

        return $this->withModel($this->ollama->generate($ollamaModel, $messages), $ollamaModel);
    }

    private function withModel(array $reply, string $model): array
    {
        $reply['model'] = $model;

        return $reply;
    }
}
