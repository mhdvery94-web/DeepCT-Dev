<?php

// Fresh PHP process: a fatal allocation must fail the parent regression test.
require __DIR__.'/../../../vendor/autoload.php';

$width = 1048576;
$height = 7;
$data = str_repeat(pack('v', 12345), $width * $height);
$tiff = 'II'.pack('v', 42).pack('V', 8 + strlen($data)).$data;
$ifd = pack('v', 8);
foreach ([[256, 4, $width], [257, 4, $height], [258, 3, 16], [259, 3, 1],
    [262, 3, 1], [273, 4, 8], [277, 3, 1], [279, 4, strlen($data)]] as [$tag, $type, $value]) {
    $ifd .= pack('vvVV', $tag, $type, 1, $value);
}
$tiff .= $ifd.pack('V', 0);
unset($data);
$metrics = new App\Services\FrameMetrics(new App\Services\TiffPreview());
$rejected = [];
foreach (['compare', 'compareMidpoint'] as $method) {
    try {
        $metrics->$method(...array_fill(0, $method === 'compare' ? 2 : 3, $tiff));
    } catch (RuntimeException $e) {
        if ($e->getMessage() !== 'Evaluation supports frame widths up to 4096 pixels.') {
            throw $e;
        }
        $rejected[] = $method;
    }
}
echo json_encode(['rejected' => $rejected, 'peak_bytes' => memory_get_peak_usage(true)], JSON_THROW_ON_ERROR), "\n";
