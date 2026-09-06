<?php

namespace App\Services;

use App\Models\AnalysisRecord;

/**
 * The index that travels inside a results archive.
 *
 * The archive is what survives. Results are deleted 24 hours after they are
 * made, so six months from now this file may be the only thing left that can
 * say which of these images came off a neutron beamline and which a model
 * drew — let alone which were drawn between two frames the model had already
 * drawn itself.
 *
 * CSV rather than JSON, and alongside `metadata.json` rather than instead of
 * it: the people who open these are as likely to reach for a spreadsheet as
 * for a parser.
 */
class ResultManifest
{
    /**
     * One row per frame in the archive.
     *
     * @param array<int, string> $inputFiles  storage paths, scanned frames
     * @param array<int, string> $outputFiles storage paths, generated frames
     */
    public function csv(
        AnalysisRecord $record,
        array $inputFiles,
        array $outputFiles
    ): string {
        $provenance = [];
        foreach ($record->frame_provenance ?? [] as $entry) {
            if (isset($entry['frame'])) {
                $provenance[$entry['frame']] = $entry;
            }
        }

        $rows = [
            ['frame', 'origin', 'interpolated_from', 'generation', 'synthetic_parents'],
        ];

        foreach ($inputFiles as $file) {
            $rows[] = [basename($file), 'scanned', '', '', ''];
        }

        foreach ($outputFiles as $file) {
            $name = basename($file);
            $entry = $provenance[$name] ?? null;

            $rows[] = [
                $name,
                'generated',
                // `1+5` rather than a bare list, so the cell stays one cell
                // when a spreadsheet meets a comma.
                $entry ? implode('+', $entry['from'] ?? []) : '',
                $entry['generation'] ?? '',
                $entry['synthetic_parents'] ?? '',
            ];
        }

        $csv = '';
        foreach ($rows as $row) {
            $csv .= implode(',', array_map($this->escape(...), $row)) . "\n";
        }

        return $csv;
    }

    private function escape(mixed $cell): string
    {
        $value = (string) $cell;

        return str_contains($value, ',') || str_contains($value, '"')
            ? '"' . str_replace('"', '""', $value) . '"'
            : $value;
    }
}
