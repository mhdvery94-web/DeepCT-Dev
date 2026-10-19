<?php

namespace App\Services;

/** Read only the versioned repository corpus: questions never choose a file or URL. */
class AiKnowledge
{
    public function retrieve(string $question): array
    {
        $question = mb_strtolower(mb_substr($question, 0, 8000));
        if (preg_match('~https?://|/etc/|/workspace/|\b(secret|secrets|rahasia|password|passwd|token|bypass)\b|pengguna lain|other users?~u', $question)) {
            return [];
        }
        $ranked = [];
        foreach ($this->corpus() as $index => $entry) {
            $score = 0;
            foreach ($entry['keywords'] as $keyword) {
                if (preg_match('/(?<![\pL\pN])'.preg_quote($keyword, '/').'(?![\pL\pN])/u', $question)) {
                    $score++;
                }
            }
            if ($score > 0) {
                $ranked[] = ['score' => $score, 'order' => $index, 'document' => $this->source($entry)];
            }
        }
        usort($ranked, fn ($a, $b) => ($b['score'] <=> $a['score']) ?: ($a['order'] <=> $b['order']));

        return array_column(array_slice($ranked, 0, 2), 'document');
    }

    /** Recheck snippets against the controlled corpus before rendering citations. */
    public function trusted(array $source): ?array
    {
        foreach ($this->corpus() as $entry) {
            $document = $this->source($entry);
            if ($source == $document) {
                return $document;
            }
        }

        return null;
    }

    private function corpus(): array
    {
        $data = json_decode(file_get_contents(resource_path('ai/sop.json')), true, 8, JSON_THROW_ON_ERROR);

        return array_values(array_filter($data['documents'] ?? [], fn ($entry) => is_array($entry)
            && is_string($entry['id'] ?? null) && preg_match('/\Adeepct-sop-[a-z-]+\z/', $entry['id'])
            && is_string($entry['version'] ?? null) && strlen($entry['version']) <= 40
            && is_string($entry['title'] ?? null) && mb_strlen($entry['title']) <= 120
            && is_string($entry['text'] ?? null) && mb_strlen($entry['text']) <= 900
            && is_array($entry['keywords'] ?? null)));
    }

    private function source(array $entry): array
    {
        return ['type' => 'document', 'id' => $entry['id'], 'version' => $entry['version'],
            'title' => $entry['title'], 'text' => $entry['text']];
    }
}
