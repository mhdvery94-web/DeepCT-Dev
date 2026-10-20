<?php

namespace Tests\Feature;

use App\Jobs\ProcessDeepLearningImage;
use App\Models\AnalysisRecord;
use App\Models\Model;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Env;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class QueueSafetyTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_ct_job_reserved_for_100_seconds_cannot_be_reserved_again(): void
    {
        // A short lease duplicates GPU work while the original CT job is running.
        config(['queue' => $this->queueConfig()]);
        $queue = app('queue')->connection('database');
        $record = $this->prediction();
        $queue->push(new ProcessDeepLearningImage($record));

        $reserved = $queue->pop();
        $this->assertNotNull($reserved);
        $this->assertSame(7200, $reserved->payload()['timeout']);

        $this->travel(100)->seconds();

        $this->assertTrue($queue->pop() === null, 'A running CT job must not be reserved twice.');
        $this->assertDatabaseHas('jobs', ['id' => $reserved->getJobId(), 'attempts' => 1]);
    }

    #[DataProvider('ctLeaseOverrides')]
    public function test_ct_lease_cannot_expire_before_the_timeout_and_safety_margin(
        ?string $override,
        int $lease,
    ): void {
        // Reverting the floor, or ignoring a larger operator lease, duplicates work.
        config(['queue' => $this->queueConfig($override)]);
        $queue = app('queue')->connection('database');
        $queue->pushRaw('{}');
        $reserved = $queue->pop();
        $this->assertNotNull($reserved);

        $this->travel($lease - 1)->seconds();
        $this->assertTrue($queue->pop() === null, 'The CT lease must include its timeout and safety margin.');

        $this->travel(1)->seconds();
        $retried = $queue->pop();
        $this->assertNotNull($retried);
        $this->assertSame($reserved->getJobId(), $retried->getJobId());
        $this->assertSame(2, $retried->attempts());
    }

    public static function ctLeaseOverrides(): array
    {
        return [
            'default' => [null, 7260],
            'old override' => ['90', 7260],
            'zero override' => ['0', 7260],
            'negative override' => ['-1', 7260],
            'larger override' => ['9000', 9000],
        ];
    }

    public function test_llm_uses_an_independent_database_queue_with_a_360_second_lease(): void
    {
        // Routing LLM work onto CT, or expiring before its 300s timeout, is unsafe.
        config(['queue' => $this->queueConfig()]);
        $this->assertArrayHasKey('llm', config('queue.connections'));
        $manager = app('queue');
        $llm = $manager->connection('llm');
        $llm->pushRaw('{}');
        $this->assertNull($manager->connection('database')->pop());
        $reserved = $llm->pop();
        $this->assertNotNull($reserved);
        $this->assertDatabaseHas('jobs', ['id' => $reserved->getJobId(), 'queue' => 'llm']);

        $this->travel(359)->seconds();
        $this->assertNull($llm->pop());
        $this->travel(1)->seconds();
        $retried = $llm->pop();
        $this->assertNotNull($retried);
        $this->assertSame($reserved->getJobId(), $retried->getJobId());
    }

    private function queueConfig(?string $retryAfter = null): array
    {
        $environment = Env::getRepository();
        $previous = $environment->get('DB_QUEUE_RETRY_AFTER');
        $retryAfter === null
            ? $environment->clear('DB_QUEUE_RETRY_AFTER')
            : $environment->set('DB_QUEUE_RETRY_AFTER', $retryAfter);

        try {
            return require config_path('queue.php');
        } finally {
            $previous === null
                ? $environment->clear('DB_QUEUE_RETRY_AFTER')
                : $environment->set('DB_QUEUE_RETRY_AFTER', $previous);
        }
    }

    private function prediction(): AnalysisRecord
    {
        $model = Model::create([
            'name' => 'Live deepCT',
            'version' => 'v1',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'online',
            'is_active' => true,
        ]);

        return AnalysisRecord::create([
            'user_id' => User::factory()->create()->id,
            'model_id' => $model->id,
            'job_id' => 'queue-safety-ct',
            'file_name' => 'frames.zip',
            'input_files_count' => 2,
            'status' => 'processing',
            'expires_at' => now()->addDay(),
        ]);
    }
}
