<?php

namespace Tests\Unit;

use PHPUnit\Framework\TestCase;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;

/**
 * Byte sequences that mean a UTF-8 file was read as Windows-1252 and saved
 * again.
 *
 * An em dash is three bytes in UTF-8 (E2 80 94). A tool that reads those as
 * Windows-1252 sees three characters and writes back `â€”`; the same tool run
 * over the result produces `Ã¢â‚¬â€`, and `prediction.dart` had one that had
 * been through it three times. The admin dashboard's Recent Activity showed
 * the visible half of it: **"by Administrator â€¢ 4d ago"**.
 *
 * The damage is in the source, not in the rendering, so no charset setting
 * anywhere repairs it — and the next careless save spreads it further. This
 * test is the tripwire.
 */
class SourceEncodingTest extends TestCase
{
    private const MOJIBAKE = ['â€', 'Ã¢', 'Ãƒ', 'Â°', "Â\u{a0}"];

    private const ROOTS = ['app', 'routes', 'config', 'database', 'tests'];

    public function test_no_source_file_carries_mangled_utf8(): void
    {
        $offenders = [];

        foreach (self::ROOTS as $root) {
            // `dirname`, not `base_path()`: this extends PHPUnit's TestCase
            // rather than Laravel's, so no application is booted and the
            // helper has nothing to resolve against.
            $path = dirname(__DIR__, 2) . DIRECTORY_SEPARATOR . $root;

            if (!is_dir($path)) {
                continue;
            }

            $files = new RecursiveIteratorIterator(
                new RecursiveDirectoryIterator($path, RecursiveDirectoryIterator::SKIP_DOTS)
            );

            foreach ($files as $file) {
                if ($file->getExtension() !== 'php') {
                    continue;
                }

                // This file names the sequences on purpose.
                if ($file->getFilename() === 'SourceEncodingTest.php') {
                    continue;
                }

                foreach (file($file->getPathname()) as $number => $line) {
                    foreach (self::MOJIBAKE as $marker) {
                        if (str_contains($line, $marker)) {
                            $offenders[] = $file->getPathname() . ':' . ($number + 1)
                                . '  ' . trim($line);
                            continue 2;
                        }
                    }
                }
            }
        }

        $this->assertSame(
            [],
            $offenders,
            "Mangled UTF-8 in:\n" . implode("\n", $offenders)
        );
    }
}
