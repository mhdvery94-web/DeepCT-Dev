<?php

use App\Services\AiGroundedReply;

$provider = strtolower((string) env('AI_ASSISTANT_PROVIDER', 'ollama'));
$ollamaModel = (string) env('AI_OLLAMA_MODEL', env('AI_ASSISTANT_MODEL', 'deepseek-r1:1.5b'));
$geminiModel = (string) env('AI_GEMINI_MODEL', 'gemini-2.5-flash');

return [
    // Activation requires a separate quality gate; disabled in every fresh environment.
    'enabled' => (bool) env('AI_ASSISTANT_ENABLED', false),
    'metadata_mode' => (bool) env('AI_METADATA_MODE', false),
    // Gemini is restricted to metadata mode so prediction facts remain
    // deterministically rendered from owned backend evidence.
    'provider' => $provider,
    'base_url' => env('AI_OLLAMA_BASE_URL', 'http://127.0.0.1:11434'),
    'token' => env('AI_OLLAMA_TOKEN'),
    // Enable only for the authenticated fixed-target DeepCT gateway.
    'gateway' => (bool) env('AI_OLLAMA_GATEWAY', false),
    'ollama_model' => $ollamaModel,
    'gemini_model' => $geminiModel,
    'model' => $provider === 'ollama' ? $ollamaModel : $geminiModel,
    'gemini_api_key' => env('GEMINI_API_KEY'),
    'gemini_timeout' => (int) env('AI_GEMINI_TIMEOUT', 30),
    'prompt_version' => env('AI_METADATA_MODE', false) ? AiGroundedReply::PROMPT_VERSION : 'deepct-assistant-v1',
    'context_tokens' => (int) env('AI_CONTEXT_TOKENS', 2048),
    'output_tokens' => (int) env('AI_OUTPUT_TOKENS', 768),
    'history_messages' => 8,
    'history_characters' => 6000,
    'message_characters' => 2000,
    'temperature' => 0.6,
    'threads' => (int) env('AI_THREADS', 2),
    'http_timeout' => 260,
    'queue_limit' => 10,
    'daily_limit' => 20,
    // Explicitly shared even when the default cache is array in tests.
    'lock_store' => env('AI_LOCK_STORE', 'file'),
    'generation_lease_seconds' => 330,
];
