# Authentication Flow Test Instructions

## Prerequisites
- Laravel backend running on http://127.0.0.1:8000
- Flutter project properly configured

## Test Steps

### 1. Start Backend (Already Running)
```bash
cd be
php artisan serve
```

### 2. Start Frontend
```bash
cd fe
flutter run -d edge --web-port=3000
# OR
flutter run -d windows
```

### 3. Test Landing Page
- ✅ Should see BRIN landing page with:
  - Header with BRIN logo
  - Hero section
  - About, Research, Join sections
  - Login button in header

### 4. Test Login Flow
- Click "LOGIN" button in header
- Should navigate to login page with:
  - 40% form panel (left)
  - 60% hero image panel (right) 
  - Email and password fields
  - "AUTHENTICATE" button

### 5. Test Authentication
Use test credentials:
- **Email**: admin@brin.go.id
- **Password**: admin123

Expected flow:
1. Click AUTHENTICATE button
2. Button shows loading state: "AUTHENTICATING..."
3. API call to http://127.0.0.1:8000/api/login
4. On success:
   - Token stored in secure storage
   - User data cached
   - Navigate to Admin Dashboard (for admin role)
   - OR Navigate to User Dashboard (for user role)

### 6. Test Dashboard
- Should see placeholder dashboard with:
  - Welcome message with username
  - Logout button in header
  - Info box about features coming soon

### 7. Test Logout
- Click LOGOUT button
- Should clear auth token
- Navigate back to Landing Page

## API Endpoints Being Used
- `POST /api/login` - Login with email/password
- `GET /api/user` - Get current user (with Bearer token)
- `POST /api/logout` - Logout (with Bearer token)

## Common Issues

### Browser Connection Timeout
If Flutter can't connect to Edge browser:
- Try using Windows desktop: `flutter run -d windows`
- Or manually open http://localhost:3000 in Edge after running `flutter run -d web-server --web-port=3000`

### CORS Errors
If seeing CORS errors in browser console:
- Check Laravel CORS configuration in `config/cors.php`
- Ensure `'paths' => ['api/*']` is set
- Verify `'allowed_origins' => ['http://localhost:3000']` includes frontend URL

### Connection Refused
If can't connect to backend:
- Verify Laravel is running: `curl http://127.0.0.1:8000/api/user`
- Check database connection
- Review Laravel logs: `tail -f storage/logs/laravel.log`

## File Structure Created

```
fe/lib/
├── main.dart                           # App entry point with Provider setup
├── config/
│   └── api_config.dart                # API base URL and endpoints
├── theme/
│   └── app_theme.dart                 # BRIN design system
├── models/
│   └── user_model.dart                # User data model
├── services/
│   ├── auth_service.dart              # HTTP client and auth methods
│   └── auth_provider.dart             # State management
└── screens/
    ├── landing/
    │   └── landing_page.dart          # Public landing page
    ├── auth/
    │   └── login_page.dart            # Login form (40/60 split)
    ├── admin/
    │   └── admin_dashboard.dart       # Admin dashboard (placeholder)
    └── user/
        └── user_dashboard.dart        # User dashboard (placeholder)
```

## Next Steps (FASE 3)
1. Build complete Admin Dashboard
   - User management (add, edit, deactivate users)
   - Active/inactive users list
   - User activity history
   - Model deployment history

2. Build complete User Dashboard
   - File upload interface (.tif files)
   - Neural network prediction workflow
   - Results download
   - Prediction history

3. Implement API integration with Ngrok endpoint
   - Connect to deployed model
   - Handle recursive interpolation
   - Process predictions
   - Auto-delete after 24 hours
