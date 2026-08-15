# 📋 Product Requirements Document (PRD)

**Platform Analisis Citra Neutron CT - BRIN**

---

## 📌 Document Information

| Field | Value |
|-------|-------|
| **Product Name** | Platform Analisis Citra Neutron CT |
| **Version** | 1.0.0 |
| **Status** | Active Development |
| **Owner** | BRIN Research Team |
| **Last Updated** | August 13, 2026 |
| **Stakeholders** | BRIN Researchers, IT Team, Mahasiswa TA |

---

## 🎯 Executive Summary

### Product Vision
Menyediakan platform terintegrasi yang memungkinkan peneliti BRIN untuk melakukan interpolasi frame citra Neutron CT secara otomatis menggunakan deep learning, dengan interface yang mudah digunakan dan hasil yang akurat.

### Target Users
- **Primary**: Peneliti BRIN yang bekerja dengan citra Neutron CT
- **Secondary**: Admin IT yang mengelola platform dan users
- **Tertiary**: Mahasiswa dan affiliate researcher

### Success Metrics
- **Accuracy**: Model interpolation accuracy > 94%
- **Performance**: Prediction completion < 5 seconds
- **User Adoption**: 80% researcher menggunakan platform dalam 3 bulan
- **Uptime**: Platform availability > 99%
- **User Satisfaction**: NPS Score > 70

---

## 🔍 Problem Statement

### Current Pain Points

1. **Manual Processing**
   - Peneliti harus manual interpolasi frame menggunakan software terpisah
   - Proses memakan waktu dan tidak konsisten
   - Membutuhkan expertise teknis yang tinggi

2. **Computational Resources**
   - Laptop/PC peneliti tidak cukup powerful untuk inference
   - Model deep learning membutuhkan GPU yang mahal
   - Bottleneck pada personal computing resources

3. **No Centralized Platform**
   - Tidak ada sistem terpusat untuk tracking hasil
   - Sulit share hasil antar researcher
   - Tidak ada audit trail aktivitas

4. **Data Management**
   - File .tif berukuran besar sulit dikelola
   - Tidak ada automatic cleanup untuk storage
   - Risiko kehilangan hasil penelitian

---

## 💡 Proposed Solution

### Platform Features

#### **1. Web & Mobile Application**
- Responsive web application (Flutter Web)
- Native Android application
- Consistent UX across platforms
- Offline capability untuk view results (future)

#### **2. Automated Interpolation**
- Upload 2 frame (.tif) → Get interpolated frames
- Recursive interpolation untuk multiple gaps
- Real-time progress tracking
- High accuracy dengan GiNet TC-D model

#### **3. Cloud-Based Computation**
- GPU processing di Google Colab
- No need for local GPU
- Scalable infrastructure
- Fast inference time

#### **4. Centralized Management**
- Admin dapat manage users
- Track all prediction activities
- Monitor model performance
- Audit logs untuk compliance

#### **5. Smart Storage**
- Auto-delete results setelah 24 jam
- Warning notification sebelum delete
- Efficient storage usage
- Download results kapan saja

---

## 👥 User Personas

### Persona 1: Dr. Sarah - Senior Researcher

**Demographics:**
- Age: 45
- Role: Senior Researcher di BRIN
- Tech Savviness: Medium
- Experience: 15 tahun di bidang material science

**Goals:**
- Analyze CT scan results quickly
- Focus on research, tidak pada teknis processing
- Reliable dan reproducible results

**Pain Points:**
- Laptop tidak cukup powerful
- Manual processing memakan waktu
- Sulit track history hasil

**User Stories:**
- "Sebagai researcher, saya ingin upload 2 frame CT scan agar bisa mendapatkan frame intermediate secara otomatis"
- "Sebagai researcher, saya ingin download hasil prediksi agar bisa digunakan untuk analisis lanjutan"
- "Sebagai researcher, saya ingin lihat history prediksi saya agar bisa track progress penelitian"

---

### Persona 2: Budi - IT Administrator

**Demographics:**
- Age: 32
- Role: IT Administrator BRIN
- Tech Savviness: High
- Experience: 8 tahun di system administration

**Goals:**
- Manage user access efficiently
- Monitor system health
- Ensure data security
- Track resource usage

**Pain Points:**
- Manual user management
- Sulit track user activities
- No visibility pada model performance
- Storage management

**User Stories:**
- "Sebagai admin, saya ingin create dan manage user accounts agar bisa control access ke platform"
- "Sebagai admin, saya ingin lihat user activities agar bisa audit siapa yang menggunakan sistem"
- "Sebagai admin, saya ingin monitor model status agar bisa ensure availability"
- "Sebagai admin, saya ingin lihat storage usage agar bisa prevent over-capacity"

---

### Persona 3: Lisa - Junior Researcher (Mahasiswa TA)

**Demographics:**
- Age: 22
- Role: Mahasiswa Teknik Informatika, TA di BRIN
- Tech Savviness: High
- Experience: First time dengan Neutron CT analysis

**Goals:**
- Learn CT analysis workflow
- Complete tugas akhir requirements
- Easy-to-use tools
- Quick turnaround time

**Pain Points:**
- Steep learning curve untuk manual tools
- Limited access ke powerful hardware
- Butuh quick results untuk iterasi

**User Stories:**
- "Sebagai mahasiswa, saya ingin interface yang intuitive agar bisa langsung mulai tanpa training panjang"
- "Sebagai mahasiswa, saya ingin quick feedback dari prediksi agar bisa iterate cepat"
- "Sebagai mahasiswa, saya ingin download hasil dalam format standard agar bisa digunakan di software lain"

---

## 📊 Feature Specifications

### 1. Authentication & Authorization

#### 1.1 User Registration
**Priority**: P0 (Must Have)  
**Implementation**: Admin-only user creation

**Functional Requirements:**
- FR-AUTH-001: Admin dapat create user dengan username, email, password, role
- FR-AUTH-002: System validate email uniqueness
- FR-AUTH-003: Password minimum 8 characters, hashed dengan bcrypt
- FR-AUTH-004: User receive email notification setelah account dibuat (future)

**Non-Functional Requirements:**
- NFR-AUTH-001: Password hashing time < 500ms
- NFR-AUTH-002: Email validation real-time

**Acceptance Criteria:**
- [ ] Admin dapat create user via dashboard
- [ ] System prevent duplicate email
- [ ] User dapat login dengan credentials yang dibuat
- [ ] Activity logged untuk audit

---

#### 1.2 User Login
**Priority**: P0 (Must Have)

**Functional Requirements:**
- FR-AUTH-005: User login dengan email dan password
- FR-AUTH-006: System generate Sanctum token setelah successful login
- FR-AUTH-007: System redirect based on user role (admin/user)
- FR-AUTH-008: System track last_login_at timestamp
- FR-AUTH-009: System log login activity

**Non-Functional Requirements:**
- NFR-AUTH-003: Login process < 2 seconds
- NFR-AUTH-004: Token expiry 24 hours
- NFR-AUTH-005: Rate limiting 5 attempts per minute

**Acceptance Criteria:**
- [ ] User dapat login dengan valid credentials
- [ ] Invalid credentials show error message
- [ ] Admin redirect ke admin dashboard
- [ ] User redirect ke user dashboard
- [ ] Token stored securely di client

---

#### 1.3 User Logout
**Priority**: P0 (Must Have)

**Functional Requirements:**
- FR-AUTH-010: User dapat logout kapan saja
- FR-AUTH-011: System revoke current token
- FR-AUTH-012: System log logout activity

**Acceptance Criteria:**
- [ ] Logout button accessible dari semua pages
- [ ] Token revoked setelah logout
- [ ] User redirect ke login page
- [ ] Activity logged

---

### 2. Landing Page

#### 2.1 Public Landing Page
**Priority**: P0 (Must Have)

**Functional Requirements:**
- FR-LAND-001: Display hero section dengan BRIN branding
- FR-LAND-002: Display About section dengan platform info
- FR-LAND-003: Display Research section dengan use cases
- FR-LAND-004: Display Join section dengan access request form
- FR-LAND-005: Navigation links scroll smooth ke sections
- FR-LAND-006: Login button redirect ke login page

**Non-Functional Requirements:**
- NFR-LAND-001: Page load time < 3 seconds
- NFR-LAND-002: Responsive mobile, tablet, desktop
- NFR-LAND-003: WCAG AA accessibility compliance

**Acceptance Criteria:**
- [ ] Hero section tampil dengan animasi BRIN
- [ ] Navigation sticky di top saat scroll
- [ ] Smooth scroll ke sections saat klik nav
- [ ] Join form submit (placeholder, no actual processing yet)
- [ ] Login button navigates to login page
- [ ] Professional design sesuai BRIN brand

---

### 3. Dashboard Admin

#### 3.1 User Management
**Priority**: P0 (Must Have)

**Functional Requirements:**
- FR-ADM-001: Admin dapat view list semua users dengan pagination
- FR-ADM-002: Admin dapat search users by name, username, email
- FR-ADM-003: Admin dapat filter users by role dan status
- FR-ADM-004: Admin dapat create new user
- FR-ADM-005: Admin dapat edit user information
- FR-ADM-006: Admin dapat delete user (dengan konfirmasi)
- FR-ADM-007: Admin dapat activate/deactivate user
- FR-ADM-008: Admin dapat view user detail dengan aktivitas

**Non-Functional Requirements:**
- NFR-ADM-001: User list load time < 2 seconds
- NFR-ADM-002: Search results real-time (debounced)
- NFR-ADM-003: Pagination 15 items per page default

**Acceptance Criteria:**
- [ ] User list tampil dengan sorting dan filtering
- [ ] Create user form validate input
- [ ] Edit user preserve existing data
- [ ] Delete user require confirmation
- [ ] Toggle status update immediately
- [ ] User detail show recent activities
- [ ] All actions logged untuk audit

---

#### 3.2 Model Management
**Priority**: P1 (Should Have)

**Functional Requirements:**
- FR-ADM-009: Admin dapat view list deployed models
- FR-ADM-010: Admin dapat view model details (version, accuracy, status)
- FR-ADM-011: Admin dapat view prediction count per model
- FR-ADM-012: Admin dapat view model deployment history
- FR-ADM-013: Admin dapat change model status (online/offline)
- FR-ADM-014: Admin dapat deploy new model version (future)

**Non-Functional Requirements:**
- NFR-ADM-004: Model list load time < 1 second
- NFR-ADM-005: Real-time status indicator

**Acceptance Criteria:**
- [ ] Model info card show name, version, status, accuracy
- [ ] Status indicator dengan color coding (green/red)
- [ ] Prediction count update real-time
- [ ] Deployment history dengan timestamps
- [ ] Toggle status dengan confirmation
- [ ] Online models prioritized in list

---

#### 3.3 User Activity Monitoring
**Priority**: P1 (Should Have)

**Functional Requirements:**
- FR-ADM-015: Admin dapat view all user activities dengan pagination
- FR-ADM-016: Admin dapat filter activities by user
- FR-ADM-017: Admin dapat filter activities by type
- FR-ADM-018: Admin dapat filter activities by date range
- FR-ADM-019: Admin dapat view user-specific activity timeline
- FR-ADM-020: Admin dapat export activity logs (future)

**Non-Functional Requirements:**
- NFR-ADM-006: Activity list load time < 2 seconds
- NFR-ADM-007: Real-time activity updates via polling (every 30s)

**Acceptance Criteria:**
- [ ] Activity list show timestamp, user, type, description
- [ ] Filter by user dropdown dengan autocomplete
- [ ] Filter by type (login, upload, predict, download, etc)
- [ ] Date range picker untuk filter
- [ ] User timeline show chronological activities
- [ ] Export button (placeholder untuk v2)

---

### 4. Dashboard User

#### 4.1 File Upload Interface
**Priority**: P0 (Must Have)

**Functional Requirements:**
- FR-USR-001: User dapat upload file via drag-and-drop
- FR-USR-002: User dapat upload file via browse button
- FR-USR-003: System validate file format (.tif only)
- FR-USR-004: System validate file size (max 50MB per file)
- FR-USR-005: User dapat preview uploaded files (thumbnail)
- FR-USR-006: User dapat cancel/remove uploaded files before submit
- FR-USR-007: Upload progress indicator untuk large files

**Non-Functional Requirements:**
- NFR-USR-001: File validation real-time
- NFR-USR-002: Upload speed dependent on network
- NFR-USR-003: Client-side validation before server upload

**Acceptance Criteria:**
- [ ] Dropzone highlight saat drag over
- [ ] Accept .tif files only
- [ ] Reject files > 50MB dengan error message
- [ ] Show file name dan size setelah upload
- [ ] Remove button untuk cancel individual file
- [ ] Progress bar untuk upload
- [ ] Error handling untuk network issues

---

#### 4.2 Prediction Execution
**Priority**: P0 (Must Have)

**Functional Requirements:**
- FR-USR-008: User dapat trigger prediction setelah upload 2 files
- FR-USR-009: System queue prediction job untuk background processing
- FR-USR-010: User dapat view real-time prediction status
- FR-USR-011: System execute recursive interpolation otomatis
- FR-USR-012: System calculate processing time
- FR-USR-013: User dapat cancel prediction yang sedang processing (future)

**Non-Functional Requirements:**
- NFR-USR-004: Prediction request response < 500ms (queueing only)
- NFR-USR-005: Background job execution < 10 seconds total
- NFR-USR-006: Status polling every 3 seconds during processing

**Acceptance Criteria:**
- [ ] Predict button enabled setelah 2 files uploaded
- [ ] Prediction start immediately setelah click
- [ ] Status indicator show "Pending" → "Processing" → "Completed"
- [ ] Processing stage messages (e.g., "Interpolating frames...")
- [ ] Completion dengan success message
- [ ] Error handling dengan clear error message
- [ ] Activity logged

---

#### 4.3 Result Viewing & Download
**Priority**: P0 (Must Have)

**Functional Requirements:**
- FR-USR-014: User dapat view prediction results setelah completed
- FR-USR-015: System display input files (T0, T2) dan output file (T1)
- FR-USR-016: System display metrics (processing time, model used)
- FR-USR-017: User dapat download result file
- FR-USR-018: System display expiration warning (24 hours)
- FR-USR-019: System auto-delete files setelah 24 hours
- FR-USR-020: User dapat delete result manually sebelum expiry

**Non-Functional Requirements:**
- NFR-USR-007: Result page load time < 2 seconds
- NFR-USR-008: Download speed dependent on network
- NFR-USR-009: File served via streaming untuk large files

**Acceptance Criteria:**
- [ ] Result page show input images preview
- [ ] Result page show output image preview
- [ ] Metrics card show processing time, model version
- [ ] Download button trigger file download
- [ ] Expiration countdown visible
- [ ] Warning notification 1 hour before expiry
- [ ] Delete button require confirmation
- [ ] Expired files return 410 Gone error

---

#### 4.4 Prediction History
**Priority**: P1 (Should Have)

**Functional Requirements:**
- FR-USR-021: User dapat view list semua predictions dengan pagination
- FR-USR-022: User dapat filter predictions by status
- FR-USR-023: User dapat sort predictions by date
- FR-USR-024: User dapat search predictions by filename
- FR-USR-025: User dapat click prediction untuk view detail

**Non-Functional Requirements:**
- NFR-USR-010: History list load time < 2 seconds
- NFR-USR-011: Pagination 10 items per page

**Acceptance Criteria:**
- [ ] History list show filename, status, date, expiry
- [ ] Status color-coded (green/yellow/red/gray)
- [ ] Sort by newest/oldest
- [ ] Filter dropdown (all/pending/completed/failed)
- [ ] Search bar untuk filename
- [ ] Click row navigate to detail page
- [ ] Empty state jika no predictions yet

---

### 5. Recursive Interpolation

#### 5.1 Automatic Gap Filling
**Priority**: P0 (Must Have)

**Functional Requirements:**
- FR-INTP-001: System detect frame gap dari filename
- FR-INTP-002: System execute recursive interpolation untuk gap > 1
- FR-INTP-003: System generate semua intermediate frames
- FR-INTP-004: System save all results dengan correct naming
- FR-INTP-005: System return all generated frames ke user

**Algorithm:**
```
Input: frame_001.tif, frame_007.tif (gap = 6)

Step 1: Interpolate frame_004 (midpoint)
  - Input: frame_001 + frame_007
  - time_scalar: 0.5
  - Output: frame_004

Step 2: Interpolate frame_002 (left midpoint)
  - Input: frame_001 + frame_004
  - time_scalar: 0.5
  - Output: frame_002

Step 3: Interpolate frame_003 (left-mid midpoint)
  - Input: frame_002 + frame_004
  - time_scalar: 0.5
  - Output: frame_003

Step 4: Interpolate frame_005 (right-mid midpoint)
  - Input: frame_004 + frame_007
  - time_scalar: 0.5
  - Output: frame_005

Step 5: Interpolate frame_006 (right midpoint)
  - Input: frame_005 + frame_007
  - time_scalar: 0.5
  - Output: frame_006

Result: frame_001, 002, 003, 004, 005, 006, 007
```

**Non-Functional Requirements:**
- NFR-INTP-001: Each interpolation step < 2 seconds
- NFR-INTP-002: Total process linear time based on gap size
- NFR-INTP-003: Memory efficient (process sequentially)

**Acceptance Criteria:**
- [ ] Correctly identify frame numbers dari filename
- [ ] Generate correct number of intermediate frames
- [ ] Frame sequence continuous dan logical
- [ ] Each frame visually distinct (no duplicates)
- [ ] Filename convention consistent
- [ ] All frames downloadable

---

## 🔧 Technical Requirements

### Frontend (Flutter)

**Platform Support:**
- Web (Chrome, Firefox, Safari, Edge)
- Android (API 21+)
- iOS (future)

**Performance:**
- First Contentful Paint < 1.5s
- Time to Interactive < 3.5s
- Lighthouse Score > 90

**Dependencies:**
- Dio (HTTP client)
- Provider/Riverpod (State management)
- Flutter Secure Storage (Token storage)
- File Picker (File upload)
- Cached Network Image (Image preview)

---

### Backend (Laravel)

**Server Requirements:**
- PHP 8.2+
- MySQL 8.0+
- Redis (for queue, future)
- Storage: 100GB+ (for file storage)

**Performance:**
- API response time < 500ms (p95)
- Database query time < 100ms (p95)
- Queue job processing < 10s per job

**Security:**
- HTTPS only
- Laravel Sanctum authentication
- CORS configured
- Input validation dan sanitization
- SQL injection protection
- XSS protection

---

### AI Worker (Google Colab)

**Requirements:**
- GPU: T4 or better
- RAM: 12GB+
- Model: generator(Salinan 3 Ginet TC-D_Revisi).h5
- Framework: TensorFlow 2.x

**Performance:**
- Model inference time < 2s per frame
- Ngrok tunnel stable connection
- Auto-restart on crash (monitoring)

---

## 📈 Success Metrics & KPIs

### User Metrics
- **Monthly Active Users (MAU)**: Target 50 researchers in Q1
- **Prediction Count**: Target 500 predictions per month
- **User Retention**: 80% users return within 30 days
- **Average Session Duration**: > 10 minutes

### System Metrics
- **Uptime**: > 99% availability
- **API Response Time**: p95 < 500ms
- **Prediction Success Rate**: > 95%
- **Error Rate**: < 1% of requests

### Business Metrics
- **Time Savings**: 80% reduction vs manual processing
- **Cost Efficiency**: Shared GPU vs individual laptops
- **User Satisfaction**: NPS > 70
- **Support Tickets**: < 5 per week

---

## 🚀 Release Plan

### Phase 1: MVP (Target: Week 1-2)
- [ ] Landing page dengan sections
- [ ] Login/logout functionality
- [ ] Admin: User management (CRUD)
- [ ] Admin: View user activities
- [ ] User: Upload files (T0, T2)
- [ ] User: Trigger prediction
- [ ] User: View result dan download
- [ ] Recursive interpolation implemented
- [ ] Auto-delete setelah 24 hours

### Phase 2: Enhanced Features (Target: Week 3-4)
- [ ] Admin: Model management dashboard
- [ ] User: Prediction history dengan filter/search
- [ ] Email notifications (file expiry warning)
- [ ] Real-time updates (polling/websocket)
- [ ] Better error handling dan recovery
- [ ] Performance optimization

### Phase 3: Scale & Polish (Target: Week 5-6)
- [ ] Mobile app (Android) deployment
- [ ] Advanced analytics dashboard
- [ ] Export reports (PDF/CSV)
- [ ] API rate limiting
- [ ] Backup dan disaster recovery
- [ ] User documentation dan tutorials

### Phase 4: Advanced Features (Future)
- [ ] Batch processing (multiple pairs)
- [ ] Model comparison (A/B testing)
- [ ] Custom model upload
- [ ] Collaboration features (share results)
- [ ] Integration dengan tools lain
- [ ] Dark mode

---

## 🔄 Update History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-08-13 | Initial PRD | Development Team |

---

## 📞 Feedback & Questions

Untuk pertanyaan atau feedback mengenai PRD ini, hubungi:
- **Product Owner**: admin@brin.go.id
- **Development Team**: [Contact Info]

---

**Last Updated**: August 13, 2026  
**Document Owner**: BRIN Development Team  
**Status**: Active Development
