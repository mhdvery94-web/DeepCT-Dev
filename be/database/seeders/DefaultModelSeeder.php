<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultModelSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $name = 'GiNet TC-D Interpolation Model';

        // Collapse any pre-existing duplicates (same name seeded more than once)
        // down to the oldest row, otherwise updateOrInsert() throws because the
        // match is ambiguous and the extra rows linger with a NULL endpoint_url.
        $ids = DB::table('models')->where('name', $name)->orderBy('id')->pluck('id');

        if ($ids->count() > 1) {
            DB::table('models')->whereIn('id', $ids->slice(1))->delete();
        }

        DB::table('models')->updateOrInsert(
            ['name' => $name],
            [
                'name' => $name,
                'version' => 'v3.0',
                'endpoint_url' => 'https://reaffirm-bullwhip-subzero.ngrok-free.dev/predict',
                'file_path' => 'models/generator(Salinan 3 Ginet TC-D_Revisi).h5',
                'status' => 'offline',
                'is_active' => true,
                'last_health_check' => null,
                'max_concurrent_jobs' => 1,
                'current_jobs_count' => 0,
                'accuracy' => 94.20,
                'description' => 'Deep learning model for Neutron CT frame interpolation using recursive interpolation method at t=0.5',
                'total_predictions' => 0,
                'deployed_at' => now(),
                'health_check_error' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );
    }
}
