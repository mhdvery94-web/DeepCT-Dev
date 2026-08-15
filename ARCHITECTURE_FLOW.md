# 🏗️ Architecture & Flow - BRIN Neural Network Portal

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     BRIN Neural Network Portal                   │
│                  Platform Analisis Citra Neutron CT              │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   Frontend   │◄───────►│   Backend    │◄───────►│   Database   │
│   (Flutter)  │  HTTP   │   (Laravel)  │  MySQL  │   (MySQL)    │
│              │  REST   │              │         │              │
│   Port 3000  │  API    │  Port 8000   │         │   db_aict    │
└──────────────┘         └──────────────┘         └──────────────┘
                               │
                               │ HTTP
                               ▼
                         ┌──────────────┐
                         │   AI Model   │
                         │   (Ngrok)    │
                         │   Colab GPU  │
                         └──────────────┘
```

---

## Authentication Flow (FASE 2 - COMPLETED ✅)

```
┌─────────────┐
│   Landing   │  User clicks "LOGIN" button
│    Page     │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Login     │  User enters credentials
│    Page     │  (email + password)
└──────┬──────┘
       │
       │ 1. POST /api/login
       │    { email, password }
       ▼
┌─────────────┐
│  Laravel    │  2. Validate credentials
│  Backend    │  3. Check user in database
│             │  4. Generate Sanctum token
└──────┬──────┘
       │
       │ 5. Response
       │    { token, user }
       ▼
┌─────────────┐
│  Flutter    │  6. Store token (secure storage)
│  AuthService│  7. Update AuthProvider state
└──────┬──────┘
       │
       │ 8. Navigate based on role
       ▼
┌─────────────┬─────────────┐
│   Admin     │    User     │
│  Dashboard  │  Dashboard  │
│  (if admin) │  (if user)  │
└─────────────┴─────────────┘
```

---

## User Roles & Permissions

```
┌──────────────────────────────────────────────┐
│                    Users                      │
└───────────────┬──────────────────────────────┘
                │
        ┌───────┴────────┐
        │                │
        ▼                ▼
   ┌─────────┐      ┌─────────┐
   │  Admin  │      │  User   │
   │  Role   │      │  Role   │
   └────┬────┘      └────┬────┘
        │                │
        │                │
    ┌───┴─────────┐      │
    │             │      │
    ▼             ▼      ▼
┌────────┐  ┌────────┐  ┌────────┐
│ Manage │  │ Manage │  │ Upload │
│ Users  │  │ Models │  │ Images │
└────────┘  └────────┘  └────────┘
                │          │
                │          ▼
                │      ┌────────┐
                │      │  Run   │
                │      │Predict │
                │      └────────┘
                │          │
                ▼          ▼
            ┌────────┐  ┌────────┐
            │  View  │  │Download│
            │Activity│  │Results │
            └────────┘  └────────┘
```

### Admin Permissions:
- ✅ Manage users (create, edit, delete, toggle status)
- ✅ View all user activities
- ✅ Manage AI models (deploy, status, history)
- ✅ View system analytics
- ✅ Access all features

### User Permissions:
- ✅ Upload image files (.tif format)
- ✅ Run predictions
- ✅ View own prediction history
- ✅ Download results
- ✅ View own activity
- ❌ Cannot manage users
- ❌ Cannot manage models

---

## Application Structure

### Frontend (Flutter)

```
fe/lib/
│
├── main.dart                    ← App entry point
│   └── ChangeNotifierProvider   ← State management
│       └── MaterialApp
│           └── AppInitializer   ← Auth check on startup
│
├── config/
│   └── api_config.dart          ← API endpoints
│
├── theme/
│   └── app_theme.dart           ← BRIN design system
│       ├── Colors (BRIN Red, neutrals)
│       ├── Typography (Lora + IBM Plex Sans)
│       └── Components (buttons, inputs, cards)
│
├── models/
│   └── user_model.dart          ← User data structure
│
├── services/
│   ├── auth_service.dart        ← HTTP client (Dio)
│   │   ├── login()
│   │   ├── logout()
│   │   ├── getCurrentUser()
│   │   └── Token storage
│   │
│   └── auth_provider.dart       ← State management
│       ├── user state
│       ├── loading state
│       └── error handling
│
└── screens/
    ├── landing/
    │   └── landing_page.dart    ← Public homepage
    │       ├── Header
    │       ├── Hero section
    │       ├── About section
    │       ├── Research section
    │       ├── Join section
    │       └── Footer
    │
    ├── auth/
    │   └── login_page.dart      ← Login form
    │       ├── 40% Form panel
    │       └── 60% Hero panel
    │
    ├── admin/
    │   └── admin_dashboard.dart ← Admin interface (placeholder)
    │
    └── user/
        └── user_dashboard.dart  ← User interface (placeholder)
```

### Backend (Laravel)

```
be/
│
├── routes/
│   ├── api.php                  ← API routes
│   │   ├── POST /api/login      (public)
│   │   ├── GET /api/user        (auth)
│   │   └── POST /api/logout     (auth)
│   │
│   └── web.php                  ← Web routes
│
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   └── API/
│   │   │       ├── AuthController.php
│   │   │       │   ├── login()
│   │   │       │   ├── logout()
│   │   │       │   └── me()
│   │   │       │
│   │   │       └── AnalysisController.php (existing)
│   │   │
│   │   └── Middleware/
│   │       └── RoleMiddleware.php
│   │           └── Check user role
│   │
│   ├── Models/
│   │   ├── User.php             ← User model
│   │   │   ├── HasApiTokens
│   │   │   ├── isAdmin()
│   │   │   └── isUser()
│   │   │
│   │   ├── AnalysisRecord.php   ← Prediction records
│   │   └── UserActivity.php     ← Activity logging
│   │
│   └── Jobs/
│       └── ProcessDeepLearningImage.php (existing)
│
├── database/
│   ├── migrations/
│   │   ├── create_users_table.php
│   │   ├── add_fields_to_users_table.php
│   │   ├── create_analysis_records_table.php
│   │   ├── create_user_activities_table.php
│   │   └── create_personal_access_tokens_table.php
│   │
│   └── seeders/
│       ├── AdminUserSeeder.php  ← Default admin
│       └── DefaultModelSeeder.php ← GiNet model
│
└── config/
    ├── sanctum.php              ← Token auth config
    └── cors.php                 ← CORS config
```

---

## Database Schema

```sql
┌─────────────────┐
│     users       │
├─────────────────┤
│ id              │
│ username        │
│ email           │
│ password        │
│ role            │  (admin/user)
│ is_active       │  (boolean)
│ created_at      │
│ updated_at      │
└────────┬────────┘
         │
         │ 1:N
         ▼
┌─────────────────────┐
│  user_activities    │
├─────────────────────┤
│ id                  │
│ user_id             │  FK → users.id
│ type                │  (login/logout/predict)
│ description         │
│ ip_address          │
│ created_at          │
└─────────────────────┘

         │
         │ 1:N
         ▼
┌──────────────────────┐
│  analysis_records    │
├──────────────────────┤
│ id                   │
│ user_id              │  FK → users.id
│ t0_image_path        │
│ t2_image_path        │
│ t1_result_path       │
│ status               │  (pending/processing/completed/failed)
│ processing_time      │
│ time_scalar          │
│ expires_at           │  24 hours expiry
│ created_at           │
│ updated_at           │
└──────────────────────┘

┌─────────────────────┐
│      models         │
├─────────────────────┤
│ id                  │
│ name                │
│ version             │
│ description         │
│ file_path           │
│ is_active           │
│ prediction_count    │
│ deployed_at         │
│ created_at          │
│ updated_at          │
└─────────────────────┘

┌───────────────────────────┐
│ personal_access_tokens    │
├───────────────────────────┤
│ id                        │
│ tokenable_type            │
│ tokenable_id              │
│ name                      │
│ token                     │
│ abilities                 │
│ last_used_at              │
│ expires_at                │
│ created_at                │
│ updated_at                │
└───────────────────────────┘
```

---

## API Endpoints (Current)

### Public Endpoints
```
POST /api/login
├── Request
│   ├── email: string (required)
│   └── password: string (required)
│
└── Response (200 OK)
    ├── success: true
    └── data
        ├── token: string
        └── user
            ├── id
            ├── username
            ├── email
            ├── role
            └── is_active
```

### Protected Endpoints (Requires Bearer Token)
```
GET /api/user
├── Headers
│   └── Authorization: Bearer {token}
│
└── Response (200 OK)
    ├── success: true
    └── data
        ├── id
        ├── username
        ├── email
        ├── role
        └── is_active

POST /api/logout
├── Headers
│   └── Authorization: Bearer {token}
│
└── Response (200 OK)
    └── success: true
```

---

## Prediction Flow (FASE 3 - Coming Soon)

```
┌─────────────┐
│    User     │  1. Upload T0 and T2 images (.tif)
│  Dashboard  │
└──────┬──────┘
       │
       │ 2. POST /api/predictions
       │    { files: [t0.tif, t2.tif], time_scalar: 0.5 }
       ▼
┌─────────────┐
│  Laravel    │  3. Validate files
│  Backend    │  4. Store files in storage
│             │  5. Create analysis_record (status: pending)
└──────┬──────┘
       │
       │ 6. Dispatch job to queue
       ▼
┌─────────────┐
│   Queue     │  7. Job: ProcessDeepLearningImage
│   Worker    │  8. Check frame gap
│             │  9. Implement recursive interpolation
└──────┬──────┘
       │
       │ 10. HTTP POST to Ngrok API
       │     https://reaffirm-bullwhip-subzero.ngrok-free.dev/predict
       ▼
┌─────────────┐
│   Colab     │  11. Load GiNet model
│   AI Model  │  12. Run prediction
│   (Ngrok)   │  13. Generate T1 frame(s)
└──────┬──────┘
       │
       │ 14. Response: T1 image(s)
       ▼
┌─────────────┐
│   Queue     │  15. Save result to storage
│   Worker    │  16. Update analysis_record (status: completed)
│             │  17. Set expires_at (now + 24 hours)
└──────┬──────┘
       │
       │ 18. Notify user (via polling or WebSocket)
       ▼
┌─────────────┐
│    User     │  19. View result
│  Dashboard  │  20. Download T1 image(s)
│             │  21. Auto-delete after 24 hours
└─────────────┘
```

---

## Recursive Interpolation Algorithm

When gap between frames > 1:

```
Input: T0 (frame 001), T2 (frame 007)
Gap: 7 - 1 = 6 frames missing (002, 003, 004, 005, 006)

Step 1: Predict middle frame
├── T0 = 001, T2 = 007
├── time_scalar = 0.5 (midpoint)
└── Result: T1 = 004

Step 2: Recursively fill left gap
├── T0 = 001, T2 = 004
├── time_scalar = 0.5
└── Result: T1 = 002 (approximately)

Step 3: Recursively fill left-middle gap
├── T0 = 002, T2 = 004
├── time_scalar = 0.5
└── Result: T1 = 003

Step 4: Recursively fill right gap
├── T0 = 004, T2 = 007
├── time_scalar = 0.5
└── Result: T1 = 005 (approximately)

Step 5: Recursively fill right-middle gap
├── T0 = 005, T2 = 007
├── time_scalar = 0.5
└── Result: T1 = 006

Final Result: 001, 002, 003, 004, 005, 006, 007 (complete sequence)
```

**Note**: Current implementation without recursion produces duplicate frames (005 = 006 = 004). Recursive implementation will fix this.

---

## Security Measures

### Authentication
```
┌──────────────────┐
│  User Login      │
├──────────────────┤
│ 1. Email/Pass    │
│ 2. Laravel Hash  │
│ 3. Sanctum Token │
│ 4. Secure Store  │
└──────────────────┘
```

### Authorization
```
┌──────────────────┐
│  Middleware      │
├──────────────────┤
│ auth:sanctum     │  ← Check valid token
│ role:admin       │  ← Check user role
└──────────────────┘
```

### Data Protection
```
┌──────────────────────┐
│  Security Layer      │
├──────────────────────┤
│ ✅ Password hashing   │  (bcrypt)
│ ✅ Token encryption   │  (Sanctum)
│ ✅ Secure storage     │  (Flutter)
│ ✅ HTTPS ready        │  (production)
│ ✅ CORS configured    │
│ ✅ Rate limiting      │  (planned)
│ ✅ Input validation   │
│ ✅ SQL injection      │  (Laravel ORM)
│ ✅ XSS protection     │  (Laravel)
└──────────────────────┘
```

---

## Technology Stack

```
┌────────────────────────────────────────────────────────┐
│                    Frontend (Client)                    │
├────────────────────────────────────────────────────────┤
│  Framework    : Flutter 3.x                            │
│  Language     : Dart                                   │
│  State Mgmt   : Provider                               │
│  HTTP Client  : Dio                                    │
│  Storage      : FlutterSecureStorage                   │
│  UI/UX        : Material Design 3                      │
│  Fonts        : Google Fonts (Lora + IBM Plex Sans)   │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│                   Backend (Server)                      │
├────────────────────────────────────────────────────────┤
│  Framework    : Laravel 11.x                           │
│  Language     : PHP 8.2+                               │
│  Database     : MySQL 8.0                              │
│  Auth         : Laravel Sanctum                        │
│  Queue        : Laravel Queue (database driver)        │
│  Storage      : Local filesystem                       │
│  API Style    : RESTful JSON                           │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│                   AI Model (Compute)                    │
├────────────────────────────────────────────────────────┤
│  Platform     : Google Colab (GPU)                     │
│  Framework    : TensorFlow / Keras                     │
│  Model        : GiNet TC-D v3.0                        │
│  Model File   : generator(Salinan 3 Ginet TC-D).h5    │
│  Size         : ~84 MB                                 │
│  API Gateway  : Ngrok                                  │
│  URL          : reaffirm-bullwhip-subzero.ngrok-free.dev│
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│                    Development Tools                    │
├────────────────────────────────────────────────────────┤
│  IDE          : VS Code / Kiro                         │
│  Version Ctrl : Git                                    │
│  API Testing  : Postman / cURL                         │
│  Local Server : Laragon (Windows)                      │
│  Package Mgr  : Composer (PHP) + Pub (Dart)           │
└────────────────────────────────────────────────────────┘
```

---

## Deployment Architecture (Future)

```
┌─────────────────────────────────────────────────────────┐
│                    Production Setup                      │
└─────────────────────────────────────────────────────────┘

Internet
   │
   ▼
┌────────────┐
│  Firewall  │
└──────┬─────┘
       │
       ▼
┌────────────┐
│ Web Server │  Nginx / Apache
│  (Reverse  │
│   Proxy)   │
└──────┬─────┘
       │
   ┌───┴────┐
   │        │
   ▼        ▼
┌─────┐  ┌─────┐
│ Web │  │ API │
│ App │  │ App │
│(FE) │  │(BE) │
└─────┘  └──┬──┘
            │
        ┌───┴────┐
        │        │
        ▼        ▼
    ┌──────┐ ┌──────┐
    │ MySQL│ │Queue │
    │  DB  │ │Worker│
    └──────┘ └───┬──┘
                 │
                 ▼
            ┌─────────┐
            │  Ngrok  │
            │  Colab  │
            │AI Model │
            └─────────┘
```

---

**Document Version**: 1.0  
**Last Updated**: August 13, 2026  
**Status**: FASE 2 Complete  
**Next Phase**: FASE 3 - Admin Dashboard Development
