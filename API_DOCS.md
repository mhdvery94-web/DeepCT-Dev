# 📡 API Documentation - Platform Analisis Citra Neutron CT

Dokumentasi lengkap REST API untuk backend Laravel.

**Last Updated:** 14 Agustus 2026  
**Version:** FASE 3 (Admin Management Complete)

---

## 🌐 Base URL

```
Development: http://localhost:8000/api
Production: https://your-domain.com/api
```

---

## 🔐 Authentication

Semua endpoint (kecuali `/login`) memerlukan authentication menggunakan **Laravel Sanctum**.

### Header Format
```http
Authorization: Bearer {your-token-here}
Content-Type: application/json
Accept: application/json
```

### Getting Token
Login terlebih dahulu untuk mendapatkan token:
```http
POST /api/login
```

---

## 📑 Table of Contents

1. [Authentication](#1-authentication)
2. [User Management (Admin)](#2-user-management-admin)
3. [Model Management (Admin)](#3-model-management-admin)
4. [Activity Logs (Admin)](#4-activity-logs-admin)
5. [Predictions (User)](#5-predictions-user) - Coming Soon

---

## 📚 API Endpoints

### **1. Authentication**

#### 1.1. Login
Authenticate user dan generate access token.

**Endpoint:** `POST /api/login`

**Access:** Public

**Request Body:**
```json
{
  "email": "admin@brin.go.id",
  "password": "admin123"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": 1,
      "username": "admin",
      "name": "Administrator",
      "email": "admin@brin.go.id",
      "role": "admin",
      "is_active": true,
      "last_login_at": "2026-08-13T15:30:00Z"
    },
    "token": "1|abc123xyz..."
  }
}
```

**Error Response (401):**
```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

---

#### 1.2. Logout
Revoke current access token.

**Endpoint:** `POST /api/logout`

**Access:** Authenticated

**Headers:**
```http
Authorization: Bearer {token}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

#### 1.3. Get Current User
Get authenticated user information.

**Endpoint:** `GET /api/user`

**Access:** Authenticated

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "username": "admin",
    "name": "Administrator",
    "email": "admin@brin.go.id",
    "role": "admin",
    "is_active": true,
    "last_login_at": "2026-08-13T15:30:00Z",
    "created_at": "2026-08-13T10:00:00Z"
  }
}
```

---

### **2. User Management (Admin Only)**

#### 2.1. List All Users
Get paginated list of all users.

**Endpoint:** `GET /api/admin/users`

**Access:** Admin only

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 15)
- `search` (optional): Search by name, username, or email
- `role` (optional): Filter by role (admin/user)
- `is_active` (optional): Filter by status (true/false)

**Example Request:**
```http
GET /api/admin/users?page=1&per_page=10&search=researcher&role=user&is_active=true
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 2,
        "username": "researcher",
        "name": "Dr. Sample Researcher",
        "email": "researcher@brin.go.id",
        "role": "user",
        "is_active": true,
        "last_login_at": "2026-08-13T14:20:00Z",
        "created_at": "2026-08-13T10:00:00Z",
        "predictions_count": 5
      }
    ],
    "per_page": 10,
    "total": 1,
    "last_page": 1
  }
}
```

---

#### 2.2. Create User
Create a new user (admin only).

**Endpoint:** `POST /api/admin/users`

**Access:** Admin only

**Request Body:**
```json
{
  "username": "newuser",
  "name": "Dr. New User",
  "email": "newuser@brin.go.id",
  "password": "securepassword123",
  "role": "user",
  "is_active": true
}
```

**Validation Rules:**
- `username`: required, unique, alpha_dash, max:255
- `name`: required, string, max:255
- `email`: required, email, unique
- `password`: required, min:8
- `role`: required, in:admin,user
- `is_active`: boolean (default: true)

**Success Response (201):**
```json
{
  "success": true,
  "message": "User created successfully",
  "data": {
    "id": 3,
    "username": "newuser",
    "name": "Dr. New User",
    "email": "newuser@brin.go.id",
    "role": "user",
    "is_active": true,
    "created_at": "2026-08-13T16:00:00Z"
  }
}
```

**Error Response (422):**
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "email": ["The email has already been taken."],
    "password": ["The password must be at least 8 characters."]
  }
}
```

---

#### 2.3. Get User Detail
Get specific user information.

**Endpoint:** `GET /api/admin/users/{id}`

**Access:** Admin only

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": 2,
    "username": "researcher",
    "name": "Dr. Sample Researcher",
    "email": "researcher@brin.go.id",
    "role": "user",
    "is_active": true,
    "last_login_at": "2026-08-13T14:20:00Z",
    "created_at": "2026-08-13T10:00:00Z",
    "updated_at": "2026-08-13T14:20:00Z",
    "recent_activities": [
      {
        "id": 1,
        "activity_type": "login",
        "description": "User logged in",
        "created_at": "2026-08-13T14:20:00Z"
      }
    ],
    "predictions_count": 5
  }
}
```

**Error Response (404):**
```json
{
  "success": false,
  "message": "User not found"
}
```

---

#### 2.4. Update User
Update user information.

**Endpoint:** `PUT /api/admin/users/{id}`

**Access:** Admin only

**Request Body:**
```json
{
  "name": "Dr. Updated Name",
  "email": "updated@brin.go.id",
  "role": "user",
  "is_active": true,
  "password": "newpassword123"
}
```

**Note:** All fields are optional. Password only updated if provided.

**Success Response (200):**
```json
{
  "success": true,
  "message": "User updated successfully",
  "data": {
    "id": 2,
    "username": "researcher",
    "name": "Dr. Updated Name",
    "email": "updated@brin.go.id",
    "role": "user",
    "is_active": true,
    "updated_at": "2026-08-13T16:30:00Z"
  }
}
```

---

#### 2.5. Delete User
Delete a user permanently.

**Endpoint:** `DELETE /api/admin/users/{id}`

**Access:** Admin only

**Success Response (200):**
```json
{
  "success": true,
  "message": "User deleted successfully"
}
```

**Error Response (403):**
```json
{
  "success": false,
  "message": "Cannot delete your own account"
}
```

---

#### 2.6. Toggle User Status
Activate or deactivate a user.

**Endpoint:** `POST /api/admin/users/{id}/toggle-status`

**Access:** Admin only

**Success Response (200):**
```json
{
  "success": true,
  "message": "User status updated",
  "data": {
    "id": 2,
    "is_active": false
  }
}
```

---

### **3. Model Management (Admin Only)**

#### 3.1. List Models
Get all deployed models.

**Endpoint:** `GET /api/admin/models`

**Access:** Admin only

**Query Parameters:**
- `status` (optional): Filter by status (online/offline)

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "GiNet TC-D Interpolation Model",
      "version": "v3.0",
      "file_path": "models/generator(Salinan 3 Ginet TC-D_Revisi).h5",
      "status": "online",
      "accuracy": 94.20,
      "description": "Deep learning model for Neutron CT frame interpolation",
      "total_predictions": 127,
      "deployed_at": "2026-08-01T10:00:00Z",
      "created_at": "2026-08-01T10:00:00Z",
      "updated_at": "2026-08-13T15:00:00Z"
    }
  ]
}
```

---

#### 3.2. Get Model Detail
Get specific model information.

**Endpoint:** `GET /api/admin/models/{id}`

**Access:** Admin only

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "GiNet TC-D Interpolation Model",
    "version": "v3.0",
    "file_path": "models/generator(Salinan 3 Ginet TC-D_Revisi).h5",
    "status": "online",
    "accuracy": 94.20,
    "description": "Deep learning model for Neutron CT frame interpolation using recursive interpolation method at t=0.5",
    "total_predictions": 127,
    "deployed_at": "2026-08-01T10:00:00Z",
    "recent_predictions": [
      {
        "id": 10,
        "user_name": "Dr. Sample Researcher",
        "status": "completed",
        "processing_time": "3.45 seconds",
        "created_at": "2026-08-13T15:20:00Z"
      }
    ]
  }
}
```

---

#### 3.3. Update Model Status
Change model status (online/offline).

**Endpoint:** `PUT /api/admin/models/{id}/status`

**Access:** Admin only

**Request Body:**
```json
{
  "status": "offline"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Model status updated",
  "data": {
    "id": 1,
    "status": "offline",
    "updated_at": "2026-08-13T16:00:00Z"
  }
}
```

---

#### 3.4. Deploy New Model
Deploy a new model version.

**Endpoint:** `POST /api/admin/models`

**Access:** Admin only

**Request Body (multipart/form-data):**
```
name: "GiNet TC-D v4.0"
version: "v4.0"
description: "Improved interpolation accuracy"
file: [binary .h5 file]
accuracy: 95.5
```

**Success Response (201):**
```json
{
  "success": true,
  "message": "Model deployed successfully",
  "data": {
    "id": 2,
    "name": "GiNet TC-D v4.0",
    "version": "v4.0",
    "status": "online",
    "deployed_at": "2026-08-13T16:30:00Z"
  }
}
```

---

### **4. Prediction/Analysis**

#### 4.1. Create Prediction
Upload files and start prediction.

**Endpoint:** `POST /api/predictions`

**Access:** Authenticated (Admin & User)

**Request Body (multipart/form-data):**
```
file_t0: [binary .tif file]
file_t2: [binary .tif file]
```

**File Validation:**
- Format: `.tif` only
- Size: Max 50MB per file
- MIME: image/tiff

**Success Response (201):**
```json
{
  "success": true,
  "message": "Prediction started. Results will be available in a few moments.",
  "data": {
    "id": 15,
    "user_id": 2,
    "status": "pending",
    "created_at": "2026-08-13T16:00:00Z"
  }
}
```

**Error Response (422):**
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "file_t0": ["The file must be a .tif image."],
    "file_t2": ["The file size must not exceed 50MB."]
  }
}
```

---

#### 4.2. Get Prediction Status
Check prediction status and get results.

**Endpoint:** `GET /api/predictions/{id}`

**Access:** Authenticated (Admin & User)

**Success Response - Pending (200):**
```json
{
  "success": true,
  "data": {
    "id": 15,
    "user_id": 2,
    "status": "pending",
    "created_at": "2026-08-13T16:00:00Z"
  }
}
```

**Success Response - Processing (200):**
```json
{
  "success": true,
  "data": {
    "id": 15,
    "user_id": 2,
    "status": "processing",
    "progress": "Interpolating frames...",
    "created_at": "2026-08-13T16:00:00Z",
    "updated_at": "2026-08-13T16:00:30Z"
  }
}
```

**Success Response - Completed (200):**
```json
{
  "success": true,
  "data": {
    "id": 15,
    "user_id": 2,
    "user_name": "Dr. Sample Researcher",
    "file_name": "neutron_ct_001_003",
    "status": "completed",
    "processing_time": "3.45 seconds",
    "t0_image_path": "/storage/neutron_images/inputs/user_2/1691234567_t0.tif",
    "t2_image_path": "/storage/neutron_images/inputs/user_2/1691234567_t2.tif",
    "t1_result_path": "/storage/neutron_images/results/user_2/1691234567_t1.tif",
    "result_url": "http://localhost:8000/storage/neutron_images/results/user_2/1691234567_t1.tif",
    "expires_at": "2026-08-14T16:00:45Z",
    "created_at": "2026-08-13T16:00:00Z",
    "completed_at": "2026-08-13T16:00:45Z"
  }
}
```

**Success Response - Failed (200):**
```json
{
  "success": true,
  "data": {
    "id": 15,
    "status": "failed",
    "error_message": "Model inference failed: CUDA out of memory",
    "created_at": "2026-08-13T16:00:00Z",
    "failed_at": "2026-08-13T16:01:00Z"
  }
}
```

---

#### 4.3. List User Predictions
Get all predictions for current user.

**Endpoint:** `GET /api/predictions`

**Access:** Authenticated

**Query Parameters:**
- `page` (optional): Page number
- `per_page` (optional): Items per page (default: 10)
- `status` (optional): Filter by status

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 15,
        "file_name": "neutron_ct_001_003",
        "status": "completed",
        "processing_time": "3.45 seconds",
        "expires_at": "2026-08-14T16:00:45Z",
        "created_at": "2026-08-13T16:00:00Z"
      },
      {
        "id": 14,
        "file_name": "sample_003_007",
        "status": "completed",
        "processing_time": "4.12 seconds",
        "expires_at": "2026-08-14T14:30:00Z",
        "created_at": "2026-08-13T14:30:00Z"
      }
    ],
    "per_page": 10,
    "total": 2,
    "last_page": 1
  }
}
```

---

#### 4.4. Download Result
Download prediction result file.

**Endpoint:** `GET /api/predictions/{id}/download`

**Access:** Authenticated (Owner or Admin)

**Success Response (200):**
```
Content-Type: image/tiff
Content-Disposition: attachment; filename="result_1691234567.tif"

[binary file data]
```

**Error Response (410):**
```json
{
  "success": false,
  "message": "File has expired and been deleted"
}
```

---

#### 4.5. Delete Prediction
Delete prediction and its files.

**Endpoint:** `DELETE /api/predictions/{id}`

**Access:** Authenticated (Owner or Admin)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Prediction deleted successfully"
}
```

---

### **5. User Activities (Admin Only)**

#### 5.1. List All Activities
Get all user activities with pagination.

**Endpoint:** `GET /api/admin/activities`

**Access:** Admin only

**Query Parameters:**
- `page` (optional): Page number
- `per_page` (optional): Items per page (default: 20)
- `user_id` (optional): Filter by user
- `activity_type` (optional): Filter by type
- `date_from` (optional): Filter from date (Y-m-d)
- `date_to` (optional): Filter to date (Y-m-d)

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 1,
        "user_id": 2,
        "user_name": "Dr. Sample Researcher",
        "activity_type": "prediction_started",
        "description": "Started prediction for files 001.tif and 003.tif",
        "ip_address": "127.0.0.1",
        "user_agent": "Mozilla/5.0...",
        "created_at": "2026-08-13T16:00:00Z"
      }
    ],
    "per_page": 20,
    "total": 1,
    "last_page": 1
  }
}
```

---

#### 5.2. User-Specific Activities
Get activities for a specific user.

**Endpoint:** `GET /api/admin/users/{userId}/activities`

**Access:** Admin only

**Query Parameters:** Same as 5.1

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 2,
      "name": "Dr. Sample Researcher",
      "email": "researcher@brin.go.id"
    },
    "activities": {
      "current_page": 1,
      "data": [
        {
          "id": 1,
          "activity_type": "login",
          "description": "User logged in",
          "ip_address": "127.0.0.1",
          "created_at": "2026-08-13T14:20:00Z"
        }
      ],
      "per_page": 20,
      "total": 1
    }
  }
}
```

---

## 🔔 Webhooks / Real-time Updates (Optional)

### Laravel Echo + Pusher (Future Implementation)

**Channel:** `prediction.{userId}`

**Event:** `PredictionCompleted`

**Payload:**
```json
{
  "prediction_id": 15,
  "status": "completed",
  "processing_time": "3.45 seconds",
  "result_url": "http://localhost:8000/storage/...",
  "expires_at": "2026-08-14T16:00:45Z"
}
```

---

## 📊 Response Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 200 | OK | Request successful |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid request format |
| 401 | Unauthorized | Missing or invalid token |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 410 | Gone | Resource expired (files) |
| 422 | Unprocessable Entity | Validation failed |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Service temporarily down |

---

## 🔒 Rate Limiting

### Default Limits
- **Authenticated requests**: 60 requests per minute
- **Login attempts**: 5 attempts per minute
- **File upload**: 10 uploads per hour per user
- **Admin endpoints**: 100 requests per minute

### Rate Limit Headers
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 59
X-RateLimit-Reset: 1691235600
```

### Rate Limit Exceeded Response (429):
```json
{
  "success": false,
  "message": "Too many requests. Please try again later.",
  "retry_after": 60
}
```

---

## 🧪 Testing with cURL

### Example: Login
```bash
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "email": "admin@brin.go.id",
    "password": "admin123"
  }'
```

### Example: Create User (Admin)
```bash
curl -X POST http://localhost:8000/api/admin/users \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "username": "newresearcher",
    "name": "Dr. New Researcher",
    "email": "new@brin.go.id",
    "password": "password123",
    "role": "user"
  }'
```

### Example: Upload for Prediction
```bash
curl -X POST http://localhost:8000/api/predictions \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file_t0=@/path/to/001.tif" \
  -F "file_t2=@/path/to/003.tif"
```

---

## 🔗 Postman Collection

Download Postman collection untuk testing: [Download Collection](#)

Environment variables yang diperlukan:
- `base_url`: http://localhost:8000
- `token`: (akan di-set otomatis setelah login)

---

## 📝 Error Response Format

All errors follow this consistent format:

```json
{
  "success": false,
  "message": "Error description",
  "errors": {
    "field_name": [
      "Validation error message"
    ]
  }
}
```

---

## 🚀 API Versioning

Current version: **v1**

Future versions akan menggunakan URL versioning:
```
/api/v1/predictions
/api/v2/predictions
```

---

**Last Updated**: August 13, 2026  
**Version**: 1.0.0  
**API Base URL**: http://localhost:8000/api


---

## **FASE 3 Updates - 14 Agustus 2026**

### **3. Model Management (Admin Only)**

#### 3.1. List All Models
Get paginated list of all AI models.

**Endpoint:** `GET /api/admin/models`

**Access:** Admin only

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 15)
- `status` (optional): Filter by status (online/offline/trouble)

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "GiNet TC-D Interpolation Model",
      "version": "v3.0",
      "endpoint_url": "https://your-ngrok-url.ngrok-free.dev/predict",
      "status": "online",
      "is_active": true,
      "last_health_check": "2026-08-14T11:00:00Z",
      "max_concurrent_jobs": 1,
      "current_jobs_count": 0,
      "total_predictions": 150,
      "accuracy": 94.20,
      "description": "Deep learning model for Neutron CT frame interpolation",
      "deployed_at": "2026-08-13T10:00:00Z",
      "health_check_error": null,
      "created_at": "2026-08-13T10:00:00Z"
    }
  ],
  "pagination": {
    "total": 1,
    "per_page": 15,
    "current_page": 1,
    "last_page": 1
  }
}
```

---

#### 3.2. Create Model
Tambah model baru dengan endpoint URL.

**Endpoint:** `POST /api/admin/models`

**Access:** Admin only

**Request Body:**
```json
{
  "name": "GiNet TC-D v4.0",
  "version": "v4.0",
  "endpoint_url": "https://your-ngrok-url.ngrok-free.dev/predict",
  "description": "Improved model with better accuracy",
  "max_concurrent_jobs": 2
}
```

**Success Response (201):**
```json
{
  "success": true,
  "message": "Model berhasil ditambahkan",
  "data": {
    "id": 2,
    "name": "GiNet TC-D v4.0",
    "version": "v4.0",
    "endpoint_url": "https://your-ngrok-url.ngrok-free.dev/predict",
    "status": "offline",
    "is_active": true,
    "max_concurrent_jobs": 2,
    "current_jobs_count": 0,
    "total_predictions": 0,
    "deployed_at": "2026-08-14T11:15:00Z"
  }
}
```

---

#### 3.3. Get Model Detail
Get detail dari satu model.

**Endpoint:** `GET /api/admin/models/{id}`

**Access:** Admin only

---

#### 3.4. Update Model
Update informasi model.

**Endpoint:** `PUT /api/admin/models/{id}`

**Access:** Admin only

**Request Body:**
```json
{
  "name": "GiNet TC-D v4.1",
  "version": "v4.1",
  "endpoint_url": "https://new-url.ngrok-free.dev/predict",
  "max_concurrent_jobs": 3
}
```

---

#### 3.5. Delete Model
Hapus model (tidak bisa jika ada job aktif).

**Endpoint:** `DELETE /api/admin/models/{id}`

**Access:** Admin only

**Success Response (200):**
```json
{
  "success": true,
  "message": "Model berhasil dihapus"
}
```

**Error Response (403):**
```json
{
  "success": false,
  "message": "Tidak dapat menghapus model yang sedang memproses job"
}
```

---

#### 3.6. Toggle Model Status
Aktifkan atau nonaktifkan model.

**Endpoint:** `PATCH /api/admin/models/{id}/toggle`

**Access:** Admin only

**Success Response (200):**
```json
{
  "success": true,
  "message": "Status model berhasil diupdate",
  "data": {
    "id": 1,
    "is_active": false
  }
}
```

---

#### 3.7. Health Check
Cek manual apakah model online dan responsif.

**Endpoint:** `POST /api/admin/models/{id}/health-check`

**Access:** Admin only

**Success Response (200):**
```json
{
  "success": true,
  "message": "Health check selesai",
  "data": {
    "model_id": 1,
    "status": "online",
    "response_time_ms": 245.5,
    "checked_at": "2026-08-14T11:20:00Z",
    "error": null
  }
}
```

**Status Values:**
- `online` ✅ - Model aktif dan responsif (<3 detik)
- `trouble` ⚠️ - Model aktif tapi lambat (>3 detik)
- `offline` ❌ - Model tidak dapat dijangkau

---

#### 3.8. Test Prediction
Test model dengan sample data.

**Endpoint:** `POST /api/admin/models/{id}/test`

**Access:** Admin only

**Success Response (200):**
```json
{
  "success": true,
  "message": "Test prediksi berhasil",
  "data": {
    "response_time_ms": 1234.56,
    "model_response": {
      "status": "ok",
      "message": "Model ready"
    }
  }
}
```

**Error Response (503):**
```json
{
  "success": false,
  "message": "Model sedang offline, tidak dapat melakukan test prediksi"
}
```

---

### **4. Activity Logs (Admin Only)**

#### 4.1. List All Activities
Get log aktivitas semua user dengan filter.

**Endpoint:** `GET /api/admin/activities`

**Access:** Admin only

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20)
- `user_id` (optional): Filter by user ID
- `type` (optional): Filter by activity type
- `date_from` (optional): Filter from date (YYYY-MM-DD)
- `date_to` (optional): Filter to date (YYYY-MM-DD)

**Example Request:**
```http
GET /api/admin/activities?user_id=2&type=login&date_from=2026-08-01&date_to=2026-08-14
```

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": 123,
      "user_id": 2,
      "model_id": null,
      "activity_type": "login",
      "description": "User logged in successfully",
      "ip_address": "192.168.1.100",
      "metadata": null,
      "created_at": "2026-08-14T08:30:00Z",
      "user": {
        "id": 2,
        "username": "researcher1",
        "name": "Research User",
        "email": "researcher1@brin.go.id"
      }
    }
  ],
  "pagination": {
    "total": 45,
    "per_page": 20,
    "current_page": 1,
    "last_page": 3
  }
}
```

**Activity Types:**
- `login` - User login
- `logout` - User logout
- `create_user` - Admin membuat user baru
- `update_user` - Admin update user
- `delete_user` - Admin hapus user
- `toggle_user_status` - Admin toggle user active/inactive
- `reset_password` - Admin reset password user
- `create_model` - Admin tambah model baru
- `update_model` - Admin update model
- `delete_model` - Admin hapus model
- `toggle_model_status` - Admin toggle model active/inactive
- `health_check` - Manual health check model
- `test_prediction` - Test prediksi model
- `prediction` - User melakukan prediksi
- `download` - User download hasil

---

#### 4.2. Get Activity Types
Get daftar semua tipe aktivitas yang tersedia.

**Endpoint:** `GET /api/admin/activities/types`

**Access:** Admin only

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    "login",
    "logout",
    "create_user",
    "update_user",
    "prediction",
    "download"
  ]
}
```

---

#### 4.3. Get User Activities
Get aktivitas untuk user tertentu.

**Endpoint:** `GET /api/admin/users/{id}/activities`

**Access:** Admin only

**Query Parameters:**
- `page` (optional): Page number
- `per_page` (optional): Items per page
- `type` (optional): Filter by activity type

---

### **Auto Health Check Command**

Model akan dicek otomatis setiap 5 menit via Laravel Scheduler.

**Manual Run:**
```bash
php artisan models:health-check
```

**Output:**
```
🔍 Checking health of all active models...
Checking: GiNet TC-D Interpolation Model (v3.0)...
  ✅ Online (Response time: 245.5ms)

📊 Summary:
  ✅ Online: 1
  ⚠️  Trouble: 0
  ❌ Offline: 0
```

---

## 🎯 Status Summary

**Completed (FASE 3 Backend):**
- ✅ User Management API (Full CRUD + Toggle + Reset Password)
- ✅ Model Management API (Full CRUD + Health Check + Test)
- ✅ Activity Logs API (Filtering + Pagination)
- ✅ Auto Health Check (Scheduled every 5 minutes)

**Coming Next:**
- ⏳ Upload & Prediction API (FASE 3)
- ⏳ Download API with ZIP (FASE 3)
- ⏳ Queue Management (FASE 3)
- ⏳ Auto-Cleanup Cron (FASE 3)

---


## 🧠 Kontrak Worker ML (Kaggle / Colab)

> **Terverifikasi langsung terhadap endpoint produksi, 14 Agustus 2026.**
> Acuan wajib saat mengimplementasikan `ProcessDeepLearningImage` di FASE 3.

### Endpoint

```
POST {endpoint_url}     contoh: https://xxxx.ngrok-free.dev/predict
Content-Type: multipart/form-data
```

Worker adalah aplikasi **FastAPI** yang hanya mendefinisikan satu route:
`POST /predict`. Route lain (`GET /`) mengembalikan **404 dan itu normal**.
`/docs` dan `/openapi.json` tersedia untuk inspeksi.

### Request - WAJIB multipart, BUKAN JSON

| Field | Tipe | Keterangan |
|-------|------|------------|
| `file_t0` | File TIFF | Frame batas awal |
| `file_t2` | File TIFF | Frame batas akhir |
| `time_scalar` | Form field (float) | Posisi interpolasi, 0.0-1.0 |

**Mengirim JSON selalu gagal HTTP 422.** Ini penyebab bug "model selalu
offline" sebelumnya. Balasan penolakannya:

```json
{"detail":[{"type":"missing","loc":["body","file_t0"],"msg":"Field required"},
           {"type":"missing","loc":["body","file_t2"],"msg":"Field required"},
           {"type":"missing","loc":["body","time_scalar"],"msg":"Field required"}]}
```

Contoh pemanggilan dari Laravel:

```php
$response = Http::timeout(120)
    ->withoutVerifying()
    ->withHeaders(['ngrok-skip-browser-warning' => 'true'])
    ->attach('file_t0', file_get_contents($pathT0), 'frame_000.tif')
    ->attach('file_t2', file_get_contents($pathT2), 'frame_002.tif')
    ->post($model->endpoint_url, ['time_scalar' => '0.5']);
```

### Response

**Sukses** - HTTP 200, `Content-Type: image/tiff`, body **biner**:

| Properti | Nilai |
|----------|-------|
| Dimensi | 1024 x 1024 (selalu, apa pun ukuran input) |
| Tipe data | `uint16` (16-bit grayscale) |
| Ukuran | 2.097.408 byte (1024x1024x2 + 256 byte header) |

Jangan panggil `$response->json()` - hasilnya biner. Simpan via `$response->body()`.

**Gagal (ditangani worker)** - HTTP 200 tapi JSON `{"error": "..."}`.
Selalu cek `Content-Type` sebelum menyimpan file.

### Perilaku terverifikasi

| Aspek | Hasil uji |
|-------|-----------|
| Preprocessing vs notebook evaluasi | **Identik** untuk input 1024^2, 512^2, 800x600, 2048^2 (maxdiff = 0.0) |
| Normalisasi | `2*(x-0)/65535 - 1` -> sama persis dengan notebook |
| Denormalisasi | `(pred+1)/2*65535` + clip + `uint16` -> sama persis |
| Bentuk tensor | `(1, 2, 1024, 1024, 1)` = (batch, timestep, H, W, channel) |
| `time_scalar` berpengaruh? | **Ya.** t=0->0.25->0.5->0.75->1.0 -> maxdiff 59->115->172->230 (monoton) |
| Simetri urutan input | **TIDAK simetris.** `predict(t0,t2,0.25)` != `predict(t2,t0,0.75)` (meandiff 1202) |
| Latensi 1024^2 | ~3,6 detik/prediksi (rata-rata 3 run) |
| Estimasi 100 frame | ~6 menit |

> **Penting untuk interpolasi rekursif:** karena model **tidak simetris**,
> `file_t0` harus selalu frame bernomor **lebih kecil** dan `file_t2` bernomor
> **lebih besar**. Menukar urutannya menghasilkan citra berbeda dan salah.

### Rotasi URL ngrok

URL berubah setiap Kaggle/Colab restart. Update lewat
**Admin -> Model Management -> Edit -> Endpoint URL**, bukan `.env`.
Sistem otomatis health check ulang setelah URL disimpan.
`NGROK_API_URL` di `.env` **tidak dibaca kode manapun** (peninggalan lama).

### Health check

Probe memakai `GET` ke root tunnel (bukan `/predict`) agar tidak memicu
inferensi GPU. Status 200/404/405/422 = **hidup**; tunnel mati dideteksi lewat
header `ngrok-error-code` (`ERR_NGROK_3200`).
Implementasi: `app/Services/ModelHealthChecker.php`.

---


### Troubleshooting: model tiba-tiba OFFLINE

| Pesan `health_check_error` | Arti | Tindakan |
|---|---|---|
| `Tunnel is not running (ERR_NGROK_3200)` | Notebook Kaggle/Colab berhenti (session timeout / dihentikan) | Jalankan ulang cell, salin URL baru ke Admin -> Model Management -> Edit |
| `cURL error 6: Could not resolve host` | URL salah ketik / domain tidak ada | Periksa ejaan URL |
| `cURL error 7: Failed to connect` | Tidak ada yang mendengarkan di port tersebut | Pastikan uvicorn berjalan |
| `Endpoint URL is not set` | Kolom endpoint kosong | Isi endpoint URL |
| `Slow response: >5000ms` (status `trouble`) | Tunnel/GPU lambat, tapi hidup | Biasanya sementara; cek beban Kaggle |

Catatan: session Kaggle gratis berhenti otomatis setelah idle beberapa jam,
jadi status `ERR_NGROK_3200` adalah kejadian normal sehari-hari, bukan bug.
Edge ngrok tetap membalas HTTP 404 walau tunnel mati, karena itu deteksi
mengandalkan header `ngrok-error-code`, bukan status code.

---

**Dokumentasi akan diupdate seiring development berlanjut.**
