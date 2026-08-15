# 🏗️ Arsitektur Sistem - Platform Analisis Citra Neutron CT

Dokumen ini menjelaskan arsitektur sistem secara detail, termasuk komponen, interaksi, dan alur data dalam platform.

---

## 📐 Arsitektur High-Level

Platform ini menggunakan arsitektur **Hybrid Cloud-NAS** yang membagi beban kerja ke dalam tiga lapisan (tier) utama:

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT TIER                              │
│                                                                   │
│  ┌──────────────────┐              ┌──────────────────┐         │
│  │  Flutter Web     │              │  Flutter Mobile  │         │
│  │  Application     │              │  (Android)       │         │
│  └────────┬─────────┘              └────────┬─────────┘         │
│           │                                 │                    │
│           └────────────────┬────────────────┘                    │
│                            │                                     │
└────────────────────────────┼─────────────────────────────────────┘
                             │ HTTPS/REST API
                             │
┌────────────────────────────┼─────────────────────────────────────┐
│                            │  GATEWAY & STORAGE TIER             │
│                            ▼                                      │
│  ┌──────────────────────────────────────────────────┐           │
│  │         Laravel 12 API Gateway                    │           │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │           │
│  │  │ Auth        │  │ File Upload │  │ Queue    │ │           │
│  │  │ Controller  │  │ Handler     │  │ Jobs     │ │           │
│  │  └─────────────┘  └─────────────┘  └──────────┘ │           │
│  └────────┬──────────────────┬──────────────────────┘           │
│           │                  │                                   │
│  ┌────────▼────────┐  ┌──────▼──────────────────────┐          │
│  │  MySQL Database │  │  Local Storage (NAS Sim)    │          │
│  │  - Users        │  │  - Input Images (.tif)      │          │
│  │  - Records      │  │  - Result Images (.tif)     │          │
│  │  - Models       │  │  - Temp Files               │          │
│  └─────────────────┘  └─────────────────────────────┘          │
│                                                                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │ HTTP POST (Ngrok Tunnel)
                             │
┌────────────────────────────┼─────────────────────────────────────┐
│                            │  COMPUTE TIER (Cloud GPU)           │
│                            ▼                                      │
│  ┌──────────────────────────────────────────────────┐           │
│  │         Google Colab + FastAPI Server            │           │
│  │  ┌─────────────────────────────────────────┐    │           │
│  │  │  Model: GiNet TC-D v3.0                 │    │           │
│  │  │  - Load .h5 model                       │    │           │
│  │  │  - Recursive Interpolation Engine       │    │           │
│  │  │  - GPU-accelerated inference            │    │           │
│  │  └─────────────────────────────────────────┘    │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                   │
│  Ngrok Tunnel: https://xxx.ngrok-free.dev/predict               │
└───────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Komponen Sistem

### 1. **Client Tier (Flutter)**

#### **Responsibility**
- User interface dan user experience
- Input validation
- File selection dan preview
- Display hasil prediksi
- Session management

#### **Teknologi**
- Flutter SDK (Dart)
- Material Design 3
- Dio (HTTP client)
- Provider/Riverpod (State management)

#### **Screens**
```
Landing Page (Public)
├── Hero Section (dengan animasi BRIN)
├── About Section
├── Research Section
└── Join Section

Login Portal
├── Email/Password Form
└── Role-based redirect

Dashboard Admin
├── User Management
│   ├── List Users
│   ├── Create User
│   ├── Edit User
│   └── View Activity History
├── Model Management
│   ├── Model Info
│   ├── Deployment History
│   └── Status Monitoring
└── Settings

Dashboard User
├── Upload Interface
│   ├── Drag & Drop Zone
│   ├── File Preview
│   └── Validation Feedback
├── Prediction Results
│   ├── Image Viewer (T0, T1, T2)
│   ├── Metrics Display
│   └── Download/Delete Actions
├── History
└── Settings
```

---

### 2. **Gateway & Storage Tier (Laravel)**

#### **Responsibility**
- API Gateway untuk semua requests
- Authentication & Authorization
- File management (upload, storage, retrieval)
- Database operations
- Queue job processing
- Business logic layer

#### **Core Modules**

##### **A. Authentication System**
```php
Middleware:
- Sanctum Authentication
- Role-based Authorization (admin/user)
- Rate Limiting

Controllers:
- AuthController
  - login()
  - logout()
  - me()
```

##### **B. User Management (Admin Only)**
```php
UserController:
- index()       // List all users
- store()       // Create new user
- show($id)     // Get user detail
- update($id)   // Update user
- destroy($id)  // Delete user
- toggleStatus($id) // Activate/Deactivate
```

##### **C. Analysis/Prediction System**
```php
AnalysisController:
- store()       // Upload T0, T2 → Trigger prediction
- show($id)     // Get prediction result
- index()       // List user predictions
- destroy($id)  // Delete prediction
- download($id) // Download result file

Jobs:
- ProcessDeepLearningImage
  - Send files to Colab API
  - Recursive interpolation logic
  - Store results
  - Update database status
```

##### **D. Model Management (Admin Only)**
```php
ModelController:
- index()       // List all models
- show($id)     // Model details
- store()       // Deploy new model
- updateStatus($id) // Online/Offline
```

##### **E. Activity Logging**
```php
UserActivityController:
- index()       // List activities
- userActivities($userId) // User-specific logs

Logged Events:
- User login/logout
- File upload
- Prediction started/completed
- File download
- User created/edited
```

#### **Database Schema**

```sql
-- Users Table
users
├── id (PK)
├── username (unique)
├── name
├── email (unique)
├── password (hashed)
├── role (enum: admin, user)
├── is_active (boolean)
├── last_login_at
├── email_verified_at
└── timestamps

-- Analysis Records
analysis_records
├── id (PK)
├── user_id (FK → users)
├── t0_image_path
├── t2_image_path
├── t1_result_path
├── file_name (original naming)
├── status (enum: pending, processing, completed, failed)
├── processing_time
├── time_scalar (float)
├── expires_at (timestamp + 24 hours)
└── timestamps

-- Models
models
├── id (PK)
├── name
├── version
├── file_path
├── status (enum: online, offline)
├── accuracy (decimal)
├── description
├── total_predictions (counter)
├── deployed_at
└── timestamps

-- User Activities
user_activities
├── id (PK)
├── user_id (FK → users)
├── activity_type (login, upload, predict, download, etc)
├── description
├── ip_address
├── user_agent
└── timestamps
```

#### **Storage Structure**
```
storage/app/public/
├── neutron_images/
│   ├── inputs/
│   │   ├── user_{id}/
│   │   │   ├── {timestamp}_t0.tif
│   │   │   └── {timestamp}_t2.tif
│   └── results/
│       ├── user_{id}/
│       │   ├── {timestamp}_t1.tif
│       │   ├── {timestamp}_t2.tif (recursive results)
│       │   └── ...
└── models/
    └── generator(Salinan 3 Ginet TC-D_Revisi).h5
```

---

### 3. **Compute Tier (Google Colab)**

#### **Responsibility**
- Load dan serve ML model
- Receive prediction requests via API
- Execute recursive interpolation
- Return hasil ke Laravel

#### **FastAPI Server**
```python
Endpoints:
POST /predict
- Input: file_t0, file_t2, time_scalar
- Process: Recursive interpolation
- Output: Binary .tif file
```

#### **Recursive Interpolation Logic**
```python
def recursive_interpolate(t0_path, t2_path):
    """
    Interpolasi rekursif untuk mengisi gap frame
    """
    results = []
    
    # Tahap 1: Prediksi frame tengah (T1)
    t1 = model.predict([t0, t2], time_scalar=0.5)
    results.append(t1)
    
    # Tahap 2: Prediksi frame kiri (antara T0 dan T1)
    if gap > 2:
        t_left = model.predict([t0, t1], time_scalar=0.5)
        results.insert(0, t_left)
    
    # Tahap 3: Prediksi frame kanan (antara T1 dan T2)
    if gap > 2:
        t_right = model.predict([t1, t2], time_scalar=0.5)
        results.append(t_right)
    
    return results
```

#### **Model Details**
- **Name**: GiNet TC-D (Generative Interpolation Network)
- **Architecture**: Modified U-Net with Temporal Conditioning
- **Input**: 2 grayscale images (.tif, 16-bit)
- **Output**: 1 interpolated frame (.tif, 16-bit)
- **Time Scalar**: 0.5 (optimal training point)
- **Accuracy**: 94.2% (validation)

#### **Model Deployment Evolution**

**Phase 1-2 (Deprecated):**
- Model `.h5` file stored locally at `storage/app/models/`
- Direct model loading in backend
- Limited to server CPU/GPU resources

**Phase 3+ (Current - Recommended):**
- Model deployed on Google Colab with dedicated GPU (T4/V100)
- Accessible via Ngrok tunnel (HTTPS endpoint)
- Backend stores only `endpoint_url` in database
- Enables horizontal scaling and better GPU utilization
- Health check system monitors model availability
- Supports multiple model versions simultaneously

---

## 🔄 Data Flow Diagrams

### Flow 1: User Prediction Request

```
┌──────────┐                                              
│  User    │                                              
│ (Flutter)│                                              
└────┬─────┘                                              
     │                                                     
     │ 1. POST /api/predict                               
     │    - file_t0.tif                                   
     │    - file_t2.tif                                   
     ▼                                                     
┌─────────────────┐                                       
│ Laravel API     │                                       
│ ┌─────────────┐ │                                       
│ │ Validate    │ │ 2. Validate files                    
│ │ files       │ │    - Check format (.tif)             
│ └──────┬──────┘ │    - Check size                      
│        │        │                                       
│ ┌──────▼──────┐ │                                       
│ │ Save to     │ │ 3. Save files to storage             
│ │ storage     │ │    /storage/neutron_images/inputs/   
│ └──────┬──────┘ │                                       
│        │        │                                       
│ ┌──────▼──────┐ │                                       
│ │ Create DB   │ │ 4. Insert analysis_record            
│ │ record      │ │    status = 'pending'                
│ └──────┬──────┘ │                                       
│        │        │                                       
│ ┌──────▼──────┐ │                                       
│ │ Dispatch    │ │ 5. Queue job                         
│ │ Job         │ │    ProcessDeepLearningImage          
│ └──────┬──────┘ │                                       
└────────┼────────┘                                       
         │                                                
         │ 6. Return response                             
         │    { id, status: 'pending' }                   
         ▼                                                
┌──────────────┐                                          
│ User gets    │                                          
│ job ID       │                                          
└──────────────┘                                          

     [Background Job Processing]                          

┌─────────────────┐                                       
│ Queue Worker    │                                       
│ ┌─────────────┐ │                                       
│ │ Update      │ │ 7. status = 'processing'             
│ │ status      │ │                                       
│ └──────┬──────┘ │                                       
│        │        │                                       
│ ┌──────▼──────┐ │                                       
│ │ POST to     │ │ 8. Send to Colab                     
│ │ Ngrok API   │ │    multipart/form-data               
│ └──────┬──────┘ │    - file_t0                         
│        │        │    - file_t2                          
└────────┼────────┘    - time_scalar=0.5                  
         │                                                
         ▼                                                
┌─────────────────┐                                       
│ Google Colab    │                                       
│ FastAPI Server  │                                       
│ ┌─────────────┐ │                                       
│ │ Load model  │ │ 9. Load .h5 model                    
│ └──────┬──────┘ │                                       
│        │        │                                       
│ ┌──────▼──────┐ │                                       
│ │ Recursive   │ │ 10. Execute interpolation            
│ │ Interpolate │ │     - Tahap 1: T0+T2 → T1           
│ │             │ │     - Tahap 2: T0+T1 → T_left       
│ └──────┬──────┘ │     - Tahap 3: T1+T2 → T_right      
│        │        │                                       
│ ┌──────▼──────┐ │                                       
│ │ Return      │ │ 11. Binary .tif file(s)              
│ │ result      │ │                                       
│ └──────┬──────┘ │                                       
└────────┼────────┘                                       
         │                                                
         ▼                                                
┌─────────────────┐                                       
│ Laravel Job     │                                       
│ ┌─────────────┐ │                                       
│ │ Save result │ │ 12. Save to storage                  
│ │ to storage  │ │     /storage/neutron_images/results/ 
│ └──────┬──────┘ │                                       
│        │        │                                       
│ ┌──────▼──────┐ │                                       
│ │ Update DB   │ │ 13. Update analysis_record           
│ │             │ │     status = 'completed'             
│ │             │ │     t1_result_path = path            
│ │             │ │     processing_time = duration       
│ │             │ │     expires_at = now + 24h           
│ └──────┬──────┘ │                                       
│        │        │                                       
│ ┌──────▼──────┐ │                                       
│ │ Log         │ │ 14. Create user_activity             
│ │ activity    │ │     type = 'prediction_completed'    
│ └─────────────┘ │                                       
└─────────────────┘                                       

┌──────────────┐                                          
│ User polls   │ 15. GET /api/predictions/{id}           
│ for result   │     Returns completed status + file URL 
└──────────────┘                                          
```

---

### Flow 2: Admin Creates User

```
┌──────────┐                                    
│  Admin   │                                    
│ (Flutter)│                                    
└────┬─────┘                                    
     │                                           
     │ 1. POST /api/admin/users                 
     │    - username                             
     │    - name                                 
     │    - email                                
     │    - password                             
     │    - role                                 
     ▼                                           
┌─────────────────┐                             
│ Laravel API     │                             
│ ┌─────────────┐ │                             
│ │ Middleware  │ │ 2. Check authentication     
│ │ - Auth      │ │    Check admin role         
│ │ - IsAdmin   │ │                             
│ └──────┬──────┘ │                             
│        │        │                             
│ ┌──────▼──────┐ │                             
│ │ Validate    │ │ 3. Validate input           
│ │ Request     │ │    - Email unique           
│ │             │ │    - Username unique        
│ └──────┬──────┘ │    - Password rules         
│        │        │                             
│ ┌──────▼──────┐ │                             
│ │ Hash        │ │ 4. bcrypt password          
│ │ Password    │ │                             
│ └──────┬──────┘ │                             
│        │        │                             
│ ┌──────▼──────┐ │                             
│ │ Create User │ │ 5. Insert to DB             
│ │             │ │    is_active = true         
│ └──────┬──────┘ │                             
│        │        │                             
│ ┌──────▼──────┐ │                             
│ │ Log         │ │ 6. Create activity log      
│ │ Activity    │ │    'user_created'           
│ └──────┬──────┘ │                             
└────────┼────────┘                             
         │                                       
         │ 7. Return new user                    
         ▼                                       
┌──────────────┐                                
│ Admin sees   │                                
│ success msg  │                                
└──────────────┘                                
```

---

## 🔐 Security Architecture

### Authentication Flow
```
1. User → Login Request (email + password)
2. Laravel → Validate credentials
3. Laravel → Generate Sanctum token
4. User → Store token in secure storage
5. All subsequent requests → Include Bearer token
6. Laravel Middleware → Verify token validity
7. Laravel Middleware → Check user role
8. Proceed to Controller or Return 401/403
```

### Authorization Matrix

| Endpoint | Admin | User | Public |
|----------|-------|------|--------|
| `/api/login` | ✅ | ✅ | ✅ |
| `/api/logout` | ✅ | ✅ | ❌ |
| `/api/admin/users/**` | ✅ | ❌ | ❌ |
| `/api/admin/models/**` | ✅ | ❌ | ❌ |
| `/api/predict` | ✅ | ✅ | ❌ |
| `/api/predictions/**` | ✅ | ✅ (own) | ❌ |
| `/api/user/profile` | ✅ | ✅ | ❌ |

### Data Security
- Password hashing: bcrypt (rounds: 12)
- Token expiration: 24 hours
- File validation: MIME type + extension check
- SQL Injection: Laravel Query Builder (prepared statements)
- XSS Protection: Laravel escape output
- CORS: Configured untuk Flutter domains

---

## 📊 Performance Considerations

### Backend Optimization
- **Queue System**: Heavy tasks (AI prediction) menggunakan queue
- **Database Indexing**: Index pada user_id, status, created_at
- **File Streaming**: Large files menggunakan streaming response
- **Cache**: Model info dan user sessions di-cache

### Frontend Optimization
- **Lazy Loading**: Images loaded on demand
- **Progressive Web App**: Service worker untuk offline capability
- **Asset Optimization**: Image compression dan lazy loading

### AI Worker Optimization
- **Model Loading**: Model di-load once pada startup
- **GPU Utilization**: Batch processing jika multiple requests
- **Result Caching**: Identical inputs menggunakan cached results (optional)

---

## 🔄 Scalability Strategy

### Horizontal Scaling
- **Laravel**: Multiple instances behind load balancer
- **Database**: MySQL replication (master-slave)
- **Storage**: Distributed file system (MinIO, S3)
- **Colab**: Multiple Colab instances dengan load balancing

### Vertical Scaling
- **Database**: Increase RAM untuk query performance
- **Storage**: Faster SSD untuk file I/O
- **Colab**: Upgrade ke Colab Pro untuk more GPU

---

## 🔍 Monitoring & Logging

### Application Logs
```php
// Laravel Log Channels
- daily: Application logs
- stack: Error logs
- queue: Job execution logs
```

### User Activity Tracking
- Login/logout events
- File upload events
- Prediction requests
- Download events
- Admin actions

### System Metrics
- API response time
- Queue job processing time
- Model inference time
- Storage usage
- Active users count

---

## 🚨 Error Handling

### Client-Side Errors (Flutter)
```dart
try {
  final response = await api.predict(t0, t2);
  // Handle success
} on NetworkException {
  // Show network error
} on ValidationException {
  // Show validation errors
} on UnauthorizedException {
  // Redirect to login
} catch (e) {
  // Show generic error
}
```

### Server-Side Errors (Laravel)
```php
try {
    // Business logic
} catch (ValidationException $e) {
    return response()->json(['error' => $e->errors()], 422);
} catch (ModelNotFoundException $e) {
    return response()->json(['error' => 'Not found'], 404);
} catch (\Exception $e) {
    Log::error($e);
    return response()->json(['error' => 'Server error'], 500);
}
```

### AI Worker Errors (Colab)
```python
try:
    result = model.predict(...)
except MemoryError:
    return JSONResponse({"error": "OOM"}, status_code=507)
except Exception as e:
    return JSONResponse({"error": str(e)}, status_code=500)
```

---

## 📝 API Communication Protocol

### Request Format
```http
POST /api/predict HTTP/1.1
Host: localhost:8000
Authorization: Bearer {token}
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="file_t0"; filename="001.tif"
Content-Type: image/tiff

[binary data]
------WebKitFormBoundary
Content-Disposition: form-data; name="file_t2"; filename="003.tif"
Content-Type: image/tiff

[binary data]
------WebKitFormBoundary--
```

### Response Format
```json
{
  "success": true,
  "message": "Prediction started",
  "data": {
    "id": 1,
    "status": "pending",
    "created_at": "2026-08-13T15:30:00Z"
  }
}
```

---

## 🎯 Design Principles

1. **Separation of Concerns**: Tiap tier punya tanggung jawab spesifik
2. **Scalability First**: Arsitektur mendukung horizontal scaling
3. **Security by Default**: Authentication & authorization di setiap layer
4. **Fail Gracefully**: Error handling yang comprehensive
5. **Monitor Everything**: Logging dan metrics untuk debugging
6. **User-Centric**: UX yang smooth dengan feedback real-time

---

**Last Updated**: August 13, 2026  
**Version**: 1.0.0
