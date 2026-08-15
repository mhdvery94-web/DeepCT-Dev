<?php

namespace App\Jobs;

use App\Models\AnalysisRecord;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;

class ProcessDeepLearningImage implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public AnalysisRecord $record) {}

    public function handle(): void
    {
        $this->record->update(['status' => 'processing']);
        $startTime = microtime(true);

        try {
            // Mengambil URL gambar dari storage Laravel
            $t0_url = Storage::disk('public')->url($this->record->t0_image_path);
            $t2_url = Storage::disk('public')->url($this->record->t2_image_path);

            // URL Ngrok dari Colab Anda
            $colabApiUrl = 'https://reaffirm-bullwhip-subzero.ngrok-free.dev/predict';

            // Mengirim request POST ke Colab
            $response = Http::post($colabApiUrl, [
                't0_image_url' => url($t0_url), 
                't2_image_url' => url($t2_url),
            ]);

            if ($response->successful()) {
                $result = $response->json();
                
                // Asumsi Colab mengembalikan JSON: {"result_path": "url_gambar_hasil"}
                $this->record->update([
                    't1_result_path' => $result['result_path'] ?? null, 
                    'status' => 'completed',
                    'processing_time' => round(microtime(true) - $startTime, 2) . 's'
                ]);
            } else {
                $this->record->update(['status' => 'failed']);
            }
        } catch (\Exception $e) {
            $this->record->update(['status' => 'failed']);
        }
    }
}