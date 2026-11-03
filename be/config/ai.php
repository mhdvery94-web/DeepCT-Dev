<?php

return [
    // Two independent switches prevent an experimental provider from becoming
    // public merely because an older deployment already enabled the worker.
    // Release approval is added only after the real-provider canary passes.
    'release_approved' => (bool) env('AI_ASSISTANT_RELEASE_APPROVED', false),
    'enabled' => (bool) env('AI_ASSISTANT_ENABLED', false)
        && (bool) env('AI_ASSISTANT_RELEASE_APPROVED', false),
    'metadata_mode' => (bool) env('AI_METADATA_MODE', false),
    'base_url' => env('AI_OLLAMA_BASE_URL', 'http://127.0.0.1:11434'),
    'token' => env('AI_OLLAMA_TOKEN'),
    // Enable only for the authenticated fixed-target DeepCT gateway.
    'gateway' => (bool) env('AI_OLLAMA_GATEWAY', false),
    'model' => env('AI_ASSISTANT_MODEL', 'deepseek-r1:1.5b'),
    'prompt_version' => env('AI_METADATA_MODE', false) ? \App\Services\AiGroundedReply::PROMPT_VERSION : 'deepct-assistant-v1',
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
