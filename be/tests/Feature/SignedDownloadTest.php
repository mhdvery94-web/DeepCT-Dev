<?php

namespace Tests\Feature;

use App\Models\AnalysisRecord;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class SignedDownloadTest extends TestCase
{
    use RefreshDatabase;

    public function test_download_link_is_owner_scoped_and_expires(): void
    {
        Storage::fake('local');
        $owner = User::create(['name' => 'Owner', 'email' => 'owner@download.test', 'password' => bcrypt('password'), 'role' => 'user', 'is_active' => true]);
        $other = User::create(['name' => 'Other', 'email' => 'other@download.test', 'password' => bcrypt('password'), 'role' => 'user', 'is_active' => true]);
        $record = AnalysisRecord::create(['user_id' => $owner->id, 'job_id' => (string) \Illuminate\Support\Str::uuid(), 'status' => 'completed', 'expires_at' => now()->addDay()]);
        $record->update(['input_folder' => $record->storageDirectory() . '/input', 'output_folder' => $record->storageDirectory() . '/output']);
        Storage::put($record->output_folder . '/frame_002.tif', 'generated frame');
        $this->apiAs($other->createToken('test')->plainTextToken)->getJson("/api/predictions/{$record->id}/download-link?kind=results")->assertNotFound();
        $link = $this->apiAs($owner->createToken('test')->plainTextToken)->getJson("/api/predictions/{$record->id}/download-link?kind=results")->assertOk()->json('data.path');
        $this->apiAs(null)->get($link)->assertOk()->assertHeader('Content-Type', 'application/zip')->assertHeader('X-Checksum-MD5');
        $owner->update(['is_active' => false]);
        $this->apiAs(null)->getJson($link)->assertForbidden();
        $owner->update(['is_active' => true]);
        $this->apiAs(null)->getJson(str_replace('kind', 'other', $link) . 'tampered')->assertForbidden();
        $this->travel(6)->minutes();
        $this->apiAs(null)->getJson($link)->assertForbidden();
    }

}
