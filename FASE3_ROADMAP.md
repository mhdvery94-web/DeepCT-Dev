# 🚀 FASE 3 - Implementation Roadmap

**Start Date**: August 14, 2026  
**Target Completion**: Week 2-3  
**Status**: Ready to Begin

---

## 📋 Implementation Order

Optimal urutan pengerjaan untuk minimize dependencies dan parallel work.

---

## PHASE 1: Database & Backend Foundation (Day 1-2)

### Day 1 Morning: Database Migrations

**Priority: HIGH - Foundation untuk semua fitur**

```bash
# 1. Update analysis_records table
php artisan make:migration add_model_id_to_analysis_records_table

# 2. Update models table
php artisan make:migration add_endpoint_fields_to_models_table

# 3. Update user_activities table  
php artisan make:migration add_metadata_to_user_activities_table

# Run migrations
php artisan migrate
```

**Files to create:**
- `database/migrations/xxxx_add_model_id_to_analysis_records_table.php`
- `database/migrations/xxxx_add_endpoint_fields_to_models_table.php`
- `database/migrations/xxxx_add_metadata_to_user_activities_table.php`

**Test:** Run migrations, check database structure

---

### Day 1 Afternoon: Backend Controllers (Part 1)

**1. UserController** (~2 hours)
```php
app/Http/Controllers/API/UserController.php

Methods:
├── index()          - List users with pagination
├── store()          - Create user with password
├── show()           - Get user detail
├── update()         - Update email, username, role
├── destroy()        - Delete user
├── toggleStatus()   - Toggle active/inactive
└── resetPassword()  - Reset to default password
```

**2. Routes**
```php
routes/api.php

Add routes:
├── GET    /api/admin/users
├── POST   /api/admin/users
├── GET    /api/admin/users/{id}
├── PUT    /api/admin/users/{id}
├── DELETE /api/admin/users/{id}
├── PATCH  /api/admin/users/{id}/toggle
└── POST   /api/admin/users/{id}/reset-password
```

**Test with cURL:**
```bash
# Create user
curl -X POST http://127.0.0.1:8000/api/admin/users \
  -H "Authorization: Bearer {token}" \
  -d "username=researcher1&email=test@brin.go.id&password=Test123&role=user"

# List users
curl -X GET http://127.0.0.1:8000/api/admin/users \
  -H "Authorization: Bearer {token}"
```

---

### Day 2 Morning: Backend Controllers (Part 2)

**3. ModelController** (~2 hours)
```php
app/Http/Controllers/API/ModelController.php

Methods:
├── index()           - List models
├── store()           - Add new model with endpoint
├── show()            - Get model detail
├── update()          - Update model
├── destroy()         - Delete model
├── toggleStatus()    - Toggle active/inactive
├── healthCheck()     - Ping model endpoint
└── testPrediction()  - Test with sample data
```

**4. Model Health Check Command**
```php
app/Console/Commands/CheckModelsHealth.php

Logic:
├── Get all active models
├── Ping each endpoint (timeout 10s)
├── Update status (online/offline/trouble)
└── Log results
```

**5. Schedule in Kernel**
```php
app/Console/Kernel.php

$schedule->command('models:health-check')
    ->everyFiveMinutes();
```

**Test:**
```bash
php artisan models:health-check
```

---

### Day 2 Afternoon: Backend Controllers (Part 3)

**6. UserActivityController** (~1 hour)
```php
app/Http/Controllers/API/UserActivityController.php

Methods:
├── index()           - List all activities with filters
└── userActivities()  - Get activities for specific user

Filters:
├── user_id
├── type (login/logout/predict/download)
├── date_from
└── date_to
```

**Test:**
```bash
curl "http://127.0.0.1:8000/api/admin/activities?user_id=1&type=login&date_from=2026-08-01"
```

---

## PHASE 2: Upload & Download Backend (Day 3-4)

### Day 3: Upload Logic

**7. AnalysisController - Upload Methods** (~3 hours)
```php
app/Http/Controllers/API/AnalysisController.php

New methods:
├── store()           - Handle ZIP upload
├── storeChunk()      - Handle chunked upload
├── validateZip()     - Validate structure
├── extractZip()      - Extract to folder
└── validateFiles()   - Check .tif files
```

**Implementation:**
```php
public function store(Request $request)
{
    // Validate
    $request->validate([
        'file' => 'required|file|mimes:zip|max:2097152', // 2 GB
        'model_id' => 'required|exists:models,id',
    ]);
    
    $user = auth()->user();
    $jobId = Uuid::uuid4()->toString();
    
    // Save ZIP
    $zipPath = $request->file('file')->storeAs(
        "temp/{$user->id}",
        "{$jobId}.zip"
    );
    
    // Extract
    $extractPath = "predictions/{$user->id}/{$jobId}/input";
    $this->extractZip($zipPath, $extractPath);
    
    // Validate files
    $files = Storage::files($extractPath);
    $this->validateFiles($files);
    
    // Create record
    $prediction = AnalysisRecord::create([
        'user_id' => $user->id,
        'job_id' => $jobId,
        'model_id' => $request->model_id,
        'input_folder' => $extractPath,
        'status' => 'pending',
        'expires_at' => now()->addHours(24),
    ]);
    
    // Dispatch job
    ProcessDeepLearningImage::dispatch($prediction);
    
    return response()->json([
        'success' => true,
        'job_id' => $jobId,
        'queue_position' => $this->getQueuePosition($prediction),
    ]);
}
```

**Test:**
```bash
curl -X POST http://127.0.0.1:8000/api/predictions \
  -H "Authorization: Bearer {token}" \
  -F "file=@dataset.zip" \
  -F "model_id=1"
```

---

### Day 4: Download Logic

**8. AnalysisController - Download Methods** (~3 hours)
```php
New methods:
├── index()            - List user predictions
├── show()             - Get prediction detail
├── downloadResults()  - Download results only
├── downloadComplete() - Download complete sequence
└── destroy()          - Delete prediction
```

**Implementation:**
```php
public function downloadResults(AnalysisRecord $prediction, $type = 'results')
{
    // Authorization
    if ($prediction->user_id !== auth()->id()) {
        abort(403);
    }
    
    // Check expired
    if ($prediction->files_deleted_at) {
        abort(410, 'Files have expired');
    }
    
    // Create ZIP
    $zipPath = $this->createZipOnDemand($prediction, $type);
    $md5 = md5_file($zipPath);
    
    return response()->streamDownload(
        fn() => readfile($zipPath),
        "results_{$prediction->job_id}.zip",
        [
            'Content-MD5' => base64_encode(hex2bin($md5)),
            'X-Checksum-MD5' => $md5,
        ]
    )->deleteFileAfterSend(true);
}
```

---

## PHASE 3: Background Job & Queue (Day 5)

**9. Update ProcessDeepLearningImage Job** (~4 hours)
```php
app/Jobs/ProcessDeepLearningImage.php

Updated logic:
├── Extract input files
├── Sort by filename (001, 002, ...)
├── Detect gaps
├── For each gap:
│   ├── Calculate time_scalar
│   ├── Call Ngrok API
│   ├── Save result to output/
│   └── Update progress
├── Update status to completed
└── Set expires_at
```

**10. QueueController** (~1 hour)
```php
app/Http/Controllers/API/QueueController.php

Methods:
├── getStatus()         - Get queue info
└── getPosition()       - Get user's position
```

---

## PHASE 4: Cleanup & Cron (Day 5 Afternoon)

**11. Cleanup Command** (~2 hours)
```php
app/Console/Commands/DeleteExpiredFiles.php

Logic:
├── Find predictions where expires_at <= now()
├── Delete physical files
├── Update files_deleted_at
├── Optionally soft delete DB record after 30 days
```

**12. Schedule**
```php
app/Console/Kernel.php

$schedule->command('cleanup:predictions')
    ->dailyAt('02:00');
```

---

## PHASE 5: Frontend Foundation (Day 6-7)

### Day 6: Admin Dashboard Layout

**13. Admin Layout** (~3 hours)
```dart
lib/screens/admin/
├── admin_dashboard_layout.dart   - Sidebar + content area
├── admin_home_screen.dart        - Dashboard home
└── widgets/
    ├── sidebar_menu.dart         - Navigation menu
    └── header_bar.dart           - Top bar
```

**14. Models for API**
```dart
lib/models/
├── paginated_response.dart       - Generic pagination
├── analysis_record_model.dart    - Prediction data
└── model_model.dart              - AI Model data
```

**15. Services**
```dart
lib/services/
├── user_service.dart             - User CRUD APIs
├── model_service.dart            - Model APIs
├── activity_service.dart         - Activity APIs
└── prediction_service.dart       - Prediction APIs
```

---

### Day 7: Admin Screens (Part 1)

**16. User Management Screen** (~4 hours)
```dart
lib/screens/admin/user_management_screen.dart

Features:
├── DataTable with users
├── Pagination controls
├── Search bar
├── Add user dialog
├── Edit user dialog
├── Delete confirmation
├── Toggle status button
└── Reset password button
```

---

## PHASE 6: Admin Screens Completion (Day 8)

**17. Model Management Screen** (~3 hours)
```dart
lib/screens/admin/model_management_screen.dart

Features:
├── Model cards grid
├── Status indicators (🟢/🔴/🟡)
├── Add model dialog
├── Health check button
├── Test prediction button
└── Model details
```

**18. User Activity Screen** (~2 hours)
```dart
lib/screens/admin/user_activity_screen.dart

Features:
├── Activity list/timeline
├── Filter dropdowns
├── Date range picker
└── Pagination
```

---

## PHASE 7: User Dashboard (Day 9-10)

### Day 9: Upload Screen

**19. Upload Screen** (~4 hours)
```dart
lib/screens/user/upload_screen.dart

Features:
├── Guidelines/checklist
├── Sample download link
├── Drag & drop zone
├── File validation
├── Smart upload (direct/streaming)
├── Progress bar with details
├── Queue position display
└── Estimated wait time
```

**20. Upload Service**
```dart
lib/services/upload_service.dart

Methods:
├── smartUpload()             - Auto-select method
├── directUpload()            - For <50 MB
├── streamingUpload()         - For >50 MB
├── validateFile()            - Client-side checks
└── calculateMd5()            - Checksum
```

---

### Day 10: Result & History Screens

**21. Prediction Result Screen** (~3 hours)
```dart
lib/screens/user/prediction_result_screen.dart

Features:
├── Status polling (every 10s)
├── Statistics display
├── Expiry countdown
├── 2 download options
├── Download verification
├── Retry mechanism
└── Delete button
```

**22. Prediction History Screen** (~2 hours)
```dart
lib/screens/user/prediction_history_screen.dart

Features:
├── Prediction list
├── Filters (status)
├── Search (job ID)
├── Sort options
└── Navigate to detail
```

---

## PHASE 8: Testing & Polish (Day 11-12)

### Day 11: Integration Testing

**23. API Testing**
- ✅ Test all endpoints with Postman
- ✅ Test authentication & authorization
- ✅ Test file upload/download
- ✅ Test queue system
- ✅ Test error handling

**24. End-to-End Testing**
- ✅ Test complete user flow (upload → process → download)
- ✅ Test admin flow (manage users/models)
- ✅ Test concurrent uploads
- ✅ Test file expiry
- ✅ Test corruption detection

---

### Day 12: Bug Fixes & Documentation

**25. Bug Fixes**
- Fix any issues found during testing
- Optimize slow queries
- Improve error messages

**26. Documentation Updates**
- Update API_DOCS.md
- Update CHANGELOG.md
- Create user guide (optional)

---

## 📊 Estimated Timeline

```
Week 1 (Day 1-5):  Backend Complete
Week 2 (Day 6-10): Frontend Complete
Week 3 (Day 11-12): Testing & Polish

Total: 12 working days
```

---

## ✅ Definition of Done

### Backend:
- [x] All controllers implemented
- [x] All routes working
- [x] Queue system functional
- [x] Cleanup cron working
- [x] All endpoints tested with cURL
- [x] Error handling in place

### Frontend:
- [x] All screens implemented
- [x] Navigation working
- [x] Upload/download functional
- [x] Verification working
- [x] Responsive layout (at least desktop)
- [x] Error messages clear

### Integration:
- [x] User can upload and download
- [x] Admin can manage users/models
- [x] Queue works correctly
- [x] Files expire after 24h
- [x] Corruption detection works
- [x] Multiple users can work simultaneously

---

## 🚀 Ready to Start!

**Next Step**: Mulai dari PHASE 1 - Database Migrations

**Command to begin:**
```bash
cd e:\deepCT-gemini\be
php artisan make:migration add_model_id_to_analysis_records_table
```

**Let's go!** 🎉
