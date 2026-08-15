# 🎯 FASE 3 - Technical Decisions & Architecture

**Date**: August 14, 2026  
**Status**: Ready for Implementation  
**Session**: Brainstorming Complete

---

## 📋 Summary of Decisions

Hasil brainstorming untuk FASE 3: Admin Dashboard & User Upload/Download functionality.

---

## 1️⃣ **User Management (Admin)**

### Requirements:
- ✅ Create user (admin set password manually)
- ✅ Edit user (email, username, role only)
- ✅ Delete permanently OR activate/deactivate user
- ✅ Reset password to default password

### Implementation:
```
Backend API:
├── POST   /api/admin/users              - Create user
├── GET    /api/admin/users              - List users (paginated)
├── GET    /api/admin/users/{id}         - Get user detail
├── PUT    /api/admin/users/{id}         - Update user
├── DELETE /api/admin/users/{id}         - Delete user
├── PATCH  /api/admin/users/{id}/toggle  - Toggle active status
└── POST   /api/admin/users/{id}/reset   - Reset password to default

Frontend:
├── User list (DataTable with pagination)
├── Add user dialog (with password field)
├── Edit user dialog (email, username, role)
├── Delete confirmation
├── Toggle active/inactive button
└── Reset password button
```

### Password Default:
**Decision**: Admin-defined default password (e.g., "BrinResearch2026")
- Shown to admin when creating user
- User forced to change on first login (future enhancement)

---

## 2️⃣ **Model Management (Admin)**

### Requirements:
- ✅ Toggle active/inactive status
- ✅ Upload model (save endpoint URL where deployed)
- ✅ Admin can run test predictions
- ✅ Dashboard shows model health status

### Implementation:
```
Database Schema (models table):
├── id
├── name                    (e.g., "GiNet TC-D v3.0")
├── version                 (e.g., "3.0")
├── description
├── endpoint_url            (Ngrok URL)
├── is_active               (boolean)
├── status                  (online/offline/trouble)
├── last_health_check       (timestamp)
├── max_concurrent_jobs     (limit)
├── current_jobs_count      (counter)
├── total_predictions       (counter)
├── deployed_at             (timestamp)
├── created_at
└── updated_at

Backend API:
├── GET    /api/admin/models              - List models
├── POST   /api/admin/models              - Add new model
├── GET    /api/admin/models/{id}         - Get detail
├── PUT    /api/admin/models/{id}         - Update model
├── DELETE /api/admin/models/{id}         - Delete model
├── PATCH  /api/admin/models/{id}/toggle  - Toggle active
├── POST   /api/admin/models/{id}/health  - Check health
└── POST   /api/admin/models/{id}/test    - Test prediction

Frontend:
├── Model cards grid
├── Status indicator (🟢 Online | 🔴 Offline | 🟡 Trouble)
├── Add model dialog (name, version, endpoint)
├── Edit model dialog
├── Toggle active/inactive
├── Health check button (manual trigger)
└── Test prediction interface
```

### Health Check Logic:
```php
// Ping Ngrok endpoint
$response = Http::timeout(10)->post($model->endpoint_url, [
    'test' => true,
]);

$status = match(true) {
    $response->failed() => 'offline',
    $response->successful() && $response->json('status') === 'ok' => 'online',
    $response->successful() && $response->slow() => 'trouble',
    default => 'offline',
};

$model->update([
    'status' => $status,
    'last_health_check' => now(),
]);
```

### Auto Health Check:
```php
// Schedule check setiap 5 menit
protected function schedule(Schedule $schedule)
{
    $schedule->command('models:health-check')
        ->everyFiveMinutes();
}
```

---

## 3️⃣ **User Activity Logs (Admin)**

### Requirements:
- ✅ View: Who, When, What, Where (IP)
- ✅ Filter: user, date range, activity type
- ✅ Pagination

### Implementation:
```
Database Schema (user_activities table):
├── id
├── user_id               (FK)
├── type                  (login/logout/predict/download)
├── description           (text)
├── ip_address
├── user_agent            (optional)
├── metadata              (JSON: extra data)
├── created_at
└── updated_at

Backend API:
├── GET /api/admin/activities?page=1&per_page=20
│   Filters:
│   ├── user_id
│   ├── type
│   ├── date_from
│   └── date_to

Frontend:
├── Activity timeline view
├── Filter dropdowns (user, type)
├── Date range picker
├── Pagination controls
└── Export to CSV (optional)
```

---

## 4️⃣ **File Upload Architecture**

### Decision: ZIP Upload with Streaming

**Why ZIP:**
- ✅ Single HTTP request instead of 1000s
- ✅ Compressed (faster upload)
- ✅ Atomic operation (all or nothing)
- ✅ Easier validation

**Upload Method:**
- ✅ Streaming upload (10 MB chunks in memory)
- ✅ No full file load (ringan di client & server)
- ✅ Hybrid: <50 MB direct, >50 MB streaming
- ✅ Resume capability

### Implementation:
```dart
// Flutter
Future<void> smartUpload(File file) async {
  final size = await file.length();
  
  if (size < 50 * 1024 * 1024) {
    await directUpload(file);
  } else {
    await streamingChunkedUpload(file);
  }
}

Future<void> streamingChunkedUpload(File file) async {
  final chunkSize = 10 * 1024 * 1024; // 10 MB
  int offset = 0;
  final totalSize = await file.length();
  
  while (offset < totalSize) {
    final chunk = await file.openRead(offset, offset + chunkSize).toList();
    
    await dio.post('/api/upload-chunk', data: {
      'chunk': chunk,
      'offset': offset,
      'total_size': totalSize,
      'job_id': jobId,
    });
    
    offset += chunkSize;
    updateProgress((offset / totalSize) * 100);
  }
}
```

```php
// Laravel
public function uploadChunk(Request $request)
{
    $jobId = $request->input('job_id');
    $offset = $request->input('offset');
    $totalSize = $request->input('total_size');
    $chunk = $request->file('chunk');
    
    $tempPath = storage_path("temp/{$jobId}.zip");
    
    // Append chunk to temp file
    $handle = fopen($tempPath, $offset === 0 ? 'w' : 'a');
    fwrite($handle, file_get_contents($chunk->path()));
    fclose($handle);
    
    // Check if complete
    if (filesize($tempPath) === (int)$totalSize) {
        // Process complete file
        $this->processUpload($jobId, $tempPath);
    }
    
    return response()->json(['received' => $offset + $chunk->getSize()]);
}
```

---

## 5️⃣ **File Download Architecture**

### Decision: On-Demand ZIP with 2 Options

**Options for User:**
1. **Results Only** (predicted files only)
2. **Complete Sequence** (originals + predicted, organized)

**Download Method:**
- ✅ Streaming response (not load to memory)
- ✅ No chunking needed (browser handles)
- ✅ Auto-resume via HTTP Range Requests
- ✅ MD5 checksum verification

### Implementation:
```php
// Laravel
public function downloadResults(AnalysisRecord $prediction, $type = 'results')
{
    // Authorization check
    $this->authorize('download', $prediction);
    
    // Check not expired
    if ($prediction->files_deleted_at) {
        abort(410, 'Files have expired');
    }
    
    // Create ZIP on-demand
    $zipPath = $this->createZipOnDemand($prediction, $type);
    $md5 = md5_file($zipPath);
    $size = filesize($zipPath);
    
    return response()->streamDownload(
        fn() => readfile($zipPath),
        "results_{$prediction->job_id}.zip",
        [
            'Content-MD5' => base64_encode(hex2bin($md5)),
            'Content-Length' => $size,
            'X-Checksum-MD5' => $md5,
        ]
    )->deleteFileAfterSend(true);
}

private function createZipOnDemand($prediction, $type)
{
    $zip = new ZipArchive();
    $tempPath = storage_path("temp/download_{$prediction->job_id}.zip");
    $zip->open($tempPath, ZipArchive::CREATE);
    
    if ($type === 'results') {
        // Add only predicted files
        foreach ($prediction->predicted_files as $file) {
            $zip->addFile(storage_path("app/{$file}"), basename($file));
        }
    } else {
        // Add organized structure
        // original/ folder
        // predicted/ folder
        // combined/ folder
        // metadata.json
    }
    
    $zip->close();
    return $tempPath;
}
```

---

## 6️⃣ **File Corruption Prevention**

### Strategy: Multi-Layer Defense

**Layers:**
1. ✅ TCP/IP checksums (automatic)
2. ✅ HTTP integrity (automatic)
3. ✅ MD5 verification (custom)
4. ✅ Retry mechanism (3 attempts)
5. ✅ User notification (if all fail)

**Expected Success Rate:** 99.9%+

### Implementation:
```dart
// Flutter - Download with verification
Future<bool> downloadWithVerification(String url, String savePath) async {
  int attempts = 0;
  const maxAttempts = 3;
  
  while (attempts < maxAttempts) {
    try {
      final response = await dio.download(url, savePath);
      
      // Get expected values from headers
      final expectedMd5 = response.headers['x-checksum-md5']?.first;
      final expectedSize = int.parse(response.headers['content-length']!.first);
      
      // Verify
      final file = File(savePath);
      if (await verifyIntegrity(file, expectedMd5!, expectedSize)) {
        return true; // Success!
      }
      
      // Verification failed, retry
      attempts++;
      await file.delete();
      showRetryMessage(attempts, maxAttempts);
      
    } catch (e) {
      attempts++;
      if (attempts >= maxAttempts) rethrow;
    }
  }
  
  return false; // All attempts failed
}

Future<bool> verifyIntegrity(File file, String expectedMd5, int expectedSize) async {
  // Check size
  if (await file.length() != expectedSize) return false;
  
  // Check MD5
  final bytes = await file.readAsBytes();
  final actualMd5 = md5.convert(bytes).toString();
  
  return actualMd5 == expectedMd5;
}
```

---

## 7️⃣ **Storage & Cleanup Strategy**

### File Structure:
```
storage/app/predictions/
├── user_1/
│   ├── job_abc123/
│   │   ├── input/          (uploaded files)
│   │   │   ├── 001.tif
│   │   │   ├── 003.tif
│   │   │   └── 007.tif
│   │   ├── output/         (predicted results)
│   │   │   ├── 002.tif
│   │   │   ├── 004.tif
│   │   │   ├── 005.tif
│   │   │   └── 006.tif
│   │   └── metadata.json
│   └── job_def456/
│       └── ...
└── user_2/
    └── ...
```

### Cleanup Schedule:
```
Timeline:
├── T+0:      User uploads, files saved
├── T+5min:   Processing complete
├── T+24h:    Auto-delete files (keep DB record)
├── T+30d:    Soft delete DB record
└── T+90d:    Hard delete (optional)

Cron Jobs:
├── Daily 2 AM:   Delete expired files
└── Every 5 min:  Health check models
```

### Implementation:
```php
// Console Command
class CleanupExpiredPredictions extends Command
{
    public function handle()
    {
        $expired = AnalysisRecord::where('expires_at', '<=', now())
            ->whereNull('files_deleted_at')
            ->get();
        
        foreach ($expired as $prediction) {
            // Delete files
            Storage::deleteDirectory("predictions/{$prediction->user_id}/{$prediction->job_id}");
            
            // Mark as deleted
            $prediction->update(['files_deleted_at' => now()]);
            
            $this->info("Deleted files for job {$prediction->job_id}");
        }
        
        // Soft delete old records (30 days)
        AnalysisRecord::where('files_deleted_at', '<=', now()->subDays(30))
            ->delete();
    }
}

// Kernel schedule
protected function schedule(Schedule $schedule)
{
    $schedule->command('cleanup:predictions')->dailyAt('02:00');
    $schedule->command('models:health-check')->everyFiveMinutes();
}
```

---

## 8️⃣ **Queue & Concurrency Handling**

### Architecture:
```
User uploads → Queue → Worker → AI Model → Results

Queue System:
├── Laravel Queue (database driver)
├── Process one job at a time per model
├── Track position in queue
└── Notify on completion
```

### Implementation:
```php
// Job
class ProcessDeepLearningImage implements ShouldQueue
{
    public $prediction;
    
    public function handle()
    {
        $this->prediction->update(['status' => 'processing']);
        
        // Extract ZIP
        $files = $this->extractZip($this->prediction->input_path);
        
        // Detect gaps
        $gaps = $this->detectGaps($files);
        
        // Recursive interpolation
        foreach ($gaps as $gap) {
            $result = $this->callModelAPI($gap);
            $this->saveResult($result);
        }
        
        $this->prediction->update([
            'status' => 'completed',
            'expires_at' => now()->addHours(24),
        ]);
        
        // Notify user
        event(new PredictionCompleted($this->prediction));
    }
}

// API to check queue
public function getQueueStatus(Request $request)
{
    $jobId = $request->input('job_id');
    
    $position = DB::table('jobs')
        ->where('created_at', '<', $job->created_at)
        ->count() + 1;
    
    return response()->json([
        'position' => $position,
        'total_queue': Queue::size(),
        'estimated_wait' => $position * 5, // 5 min per job
    ]);
}
```

---

## 9️⃣ **UI/UX Guidelines**

### Upload Page Features:
- ✅ Checklist of requirements
- ✅ Sample dataset download
- ✅ Tutorial/help section
- ✅ File validation before upload
- ✅ Progress bar with details
- ✅ Queue position indicator
- ✅ Expiry warning (24 hours)

### Download Page Features:
- ✅ 2 download options (results only / complete)
- ✅ Expiry countdown timer
- ✅ File preview/gallery
- ✅ Individual file download (optional)
- ✅ Download verification status

### Notification System:
- ✅ In-app only (no email)
- ✅ Polling every 10 seconds
- ✅ Toast notifications
- ✅ Status updates (pending/processing/completed)

---

## 🔧 **Technology Stack**

```
Backend:
├── Laravel 11.x
├── MySQL 8.0
├── Queue: Database driver
├── Storage: Local filesystem
└── Cron: Laravel Scheduler

Frontend:
├── Flutter 3.x
├── State: Provider
├── HTTP: Dio
├── Storage: flutter_secure_storage
└── File: file_picker

AI Model:
├── Platform: Google Colab
├── Gateway: Ngrok
├── Model: GiNet TC-D (.h5)
└── API: REST (POST /predict)
```

---

## 📊 **Performance Targets**

```
Upload:
├── <50 MB: Direct (1-2 min)
├── 50-500 MB: Streaming (3-10 min)
└── 500 MB-2 GB: Streaming (10-30 min)

Processing:
├── 100 frames: ~5-10 min
├── 500 frames: ~25-50 min
└── 1000 frames: ~50-100 min

Download:
├── Results (40 MB): ~30 sec
├── Complete (70 MB): ~45 sec
└── ZIP creation: 2-10 sec

Storage:
├── Per job: ~1.5 GB average
├── Cleanup: Daily at 2 AM
└── Retention: 24 hours
```

---

## ✅ **Ready for Implementation**

All technical decisions made. Next steps:
1. Update TODO.md with detailed tasks
2. Create database migrations
3. Build backend APIs
4. Build frontend UI
5. Integration testing

---

**Document Version**: 1.0  
**Last Updated**: August 14, 2026  
**Status**: ✅ Ready to Code
