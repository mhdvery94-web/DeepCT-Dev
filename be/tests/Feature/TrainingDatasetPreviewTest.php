<?php

namespace Tests\Feature;

use App\Models\TrainingDataset;
use App\Models\TrainingJob;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;
use ZipArchive;

/**
 * Looking at a dataset before a GPU spends hours on it.
 *
 * The archive is never extracted: a dataset is the largest thing this platform
 * stores, and doubling it on disk just to look would be absurd. ZipArchive
 * reads one entry at a time instead.
 */
class TrainingDatasetPreviewTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;
    private User $stranger;
    private TrainingJob $job;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');

        $this->owner = User::create([
            'name' => 'Owner', 'email' => 'owner@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);

        $this->stranger = User::create([
            'name' => 'Stranger', 'email' => 'stranger@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user', 'is_active' => true,
        ]);

        $archive = 'training/datasets/set.zip';
        Storage::put($archive, '');
        $this->writeArchive(Storage::path($archive));

        $dataset = TrainingDataset::create([
            'name' => 'Set',
            'source_type' => 'upload',
            'archive_path' => $archive,
            'uploaded_by' => $this->owner->id,
        ]);

        $this->job = TrainingJob::create([
            'name' => 'Run',
            'training_dataset_id' => $dataset->id,
            'status' => 'queued',
            'total_epochs' => 5,
            'created_by' => $this->owner->id,
        ]);
    }

    /**
     * A 16-bit greyscale TIFF built exactly the way TiffPreviewTest builds
     * one — pixels first at offset 8, then the IFD. Copied rather than
     * invented so the renderer is exercised on something it genuinely
     * understands.
     */
    private function tiff(int $w = 4, int $h = 4): string
    {
        $packed = '';
        foreach (array_fill(0, $w * $h, 30000) as $p) {
            $packed .= pack('v', $p);
        }

        $s = fn(int $v) => pack('v', $v);
        $l = fn(int $v) => pack('V', $v);

        $pixelOffset = 8;
        $ifdOffset = $pixelOffset + strlen($packed);

        $header = 'II' . $s(42) . $l($ifdOffset);

        $entry = fn(int $tag, int $type, int $count, int $value) =>
            $s($tag) . $s($type) . $l($count) .
            ($type === 3 ? $s($value) . $s(0) : $l($value));

        $ifd = $s(8)
            . $entry(256, 3, 1, $w)
            . $entry(257, 3, 1, $h)
            . $entry(258, 3, 1, 16)
            . $entry(259, 3, 1, 1)
            . $entry(262, 3, 1, 1)
            . $entry(273, 4, 1, $pixelOffset)
            . $entry(277, 3, 1, 1)
            . $entry(279, 4, 1, strlen($packed))
            . $l(0);

        return $header . $packed . $ifd;
    }

    private function writeArchive(string $absolute): void
    {
        $zip = new ZipArchive();
        $zip->open($absolute, ZipArchive::OVERWRITE | ZipArchive::CREATE);
        $zip->addFromString('frame_001.tif', $this->tiff());
        $zip->addFromString('frame_002.tif', $this->tiff());
        $zip->addFromString('notes.txt', 'not a frame');
        $zip->close();
    }

    private function token(User $user): string
    {
        return $this->tokenFor($user->email, 'password123');
    }

    public function test_the_frames_inside_the_archive_are_listed(): void
    {
        $this->apiAs($this->token($this->owner))
            ->getJson("/api/me/training/jobs/{$this->job->id}/dataset/frames")
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.name', 'frame_001.tif')
            ->assertJsonPath('data.1.name', 'frame_002.tif');
    }

    /** A README in the archive is not a frame and must not be offered. */
    public function test_a_non_frame_entry_is_not_listed(): void
    {
        $response = $this->apiAs($this->token($this->owner))
            ->getJson("/api/me/training/jobs/{$this->job->id}/dataset/frames")
            ->assertOk();

        $this->assertStringNotContainsString('notes.txt', $response->getContent());
    }

    public function test_a_frame_renders_as_a_png(): void
    {
        $this->apiAs($this->token($this->owner))
            ->get("/api/me/training/jobs/{$this->job->id}/dataset/frames/frame_001.tif/preview")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png');
    }

    /**
     * The name has to be checked against the archive's own listing. A name
     * that reaches getFromName() unchecked reads whatever it points at.
     */
    public function test_a_name_outside_the_archive_is_refused(): void
    {
        $this->apiAs($this->token($this->owner))
            ->get("/api/me/training/jobs/{$this->job->id}/dataset/frames/"
                . urlencode('../../.env') . '/preview')
            ->assertNotFound();
    }

    public function test_an_unknown_frame_is_refused(): void
    {
        $this->apiAs($this->token($this->owner))
            ->get("/api/me/training/jobs/{$this->job->id}/dataset/frames/frame_999.tif/preview")
            ->assertNotFound();
    }

    public function test_someone_elses_dataset_is_not_readable(): void
    {
        $this->apiAs($this->token($this->stranger))
            ->getJson("/api/me/training/jobs/{$this->job->id}/dataset/frames")
            ->assertNotFound();
    }

    /** The second read comes from the cache, not from the archive again. */
    public function test_a_rendered_frame_is_cached(): void
    {
        $token = $this->token($this->owner);
        $url = "/api/me/training/jobs/{$this->job->id}/dataset/frames/frame_001.tif/preview";

        $this->apiAs($token)->get($url)->assertOk();

        $cached = collect(Storage::allFiles('training/datasets/preview'))
            ->filter(fn($p) => str_ends_with($p, '.png'));

        $this->assertCount(1, $cached, 'the render should have been kept');

        $this->apiAs($token)->get($url)->assertOk();
    }
}
