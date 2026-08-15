<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AccessRequestController;
use App\Http\Controllers\API\AnalysisController;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\AvatarController;
use App\Http\Controllers\API\MeController;
use App\Http\Controllers\API\NewsController;
use App\Http\Controllers\API\PredictionUploadController;
use App\Http\Controllers\API\SupportTicketController;
use App\Http\Controllers\API\UserController;
use App\Http\Controllers\API\ModelController;
use App\Http\Controllers\API\UserActivityController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Public routes (no authentication required)
// Rate limited to 5 attempts per minute per IP (PRD NFR-AUTH-005) to block
// credential brute-forcing.
Route::post('/login', [AuthController::class, 'login'])
    ->middleware('throttle:5,1')
    ->name('api.login');

// Requests for an account, from the public landing page. Rate limited the
// same way login is: it is the other unauthenticated write path.
Route::post('/access-requests', [AccessRequestController::class, 'store'])
    ->middleware('throttle:5,1')
    ->name('api.access-requests.store');

// Support from the sign-in page, for people who cannot get in — the third and
// last unauthenticated write path. Throttled per hour rather than per minute:
// a genuine reporter files one ticket, not five a minute.
Route::post('/support/tickets/public', [SupportTicketController::class, 'storePublic'])
    ->middleware('throttle:5,60')
    ->name('api.support.tickets.public');

// Research news for the landing page slideshow. Read-only and published-only;
// the image route serves a draft to an administrator, which is why it resolves
// the token itself rather than sitting behind auth middleware.
Route::get('/news', [NewsController::class, 'index'])->name('api.news.index');
Route::get('/news/{id}/image', [NewsController::class, 'image'])->name('api.news.image');

// Protected routes (authentication required)
Route::middleware('auth:sanctum')->group(function () {
    // Auth routes
    Route::post('/logout', [AuthController::class, 'logout'])->name('api.logout');
    Route::get('/user', [AuthController::class, 'me'])->name('api.user');

    // Self-service routes for the signed-in user (any role). Everything here is
    // scoped to the caller, so no admin middleware — a researcher needs these
    // for their own dashboard.
    Route::prefix('me')->group(function () {
        Route::get('/activities', [MeController::class, 'activities'])->name('api.me.activities');
        Route::get('/stats', [MeController::class, 'stats'])->name('api.me.stats');
        Route::get('/models', [MeController::class, 'models'])->name('api.me.models');

        // Own profile photo.
        Route::post('/avatar', [AvatarController::class, 'updateOwn'])->name('api.me.avatar.update');
        Route::delete('/avatar', [AvatarController::class, 'destroyOwn'])->name('api.me.avatar.destroy');
    });

    // Serving a photo is authenticated rather than public: avatars appear
    // beside activity logs and in the user list, so every signed-in account
    // needs them, but an anonymous visitor must not be able to harvest photos
    // of the research staff by walking the ids.
    Route::get('/users/{id}/avatar', [AvatarController::class, 'show'])->name('api.users.avatar');


    // Admin routes
    Route::middleware('role:admin')->prefix('admin')->group(function () {
        // User management
        Route::get('/users', [UserController::class, 'index'])->name('api.admin.users.index');
        Route::post('/users', [UserController::class, 'store'])->name('api.admin.users.store');
        Route::get('/users/{id}', [UserController::class, 'show'])->name('api.admin.users.show');
        Route::put('/users/{id}', [UserController::class, 'update'])->name('api.admin.users.update');
        Route::delete('/users/{id}', [UserController::class, 'destroy'])->name('api.admin.users.destroy');
        Route::patch('/users/{id}/toggle', [UserController::class, 'toggleStatus'])->name('api.admin.users.toggle');
        Route::post('/users/{id}/reset-password', [UserController::class, 'resetPassword'])->name('api.admin.users.reset');

        // Someone has to be able to remove an inappropriate photo from an
        // account that is not theirs.
        Route::post('/users/{id}/avatar', [AvatarController::class, 'updateFor'])->name('api.admin.users.avatar.update');
        Route::delete('/users/{id}/avatar', [AvatarController::class, 'destroyFor'])->name('api.admin.users.avatar.destroy');
        
        // Model management
        Route::get('/models', [ModelController::class, 'index'])->name('api.admin.models.index');
        Route::post('/models', [ModelController::class, 'store'])->name('api.admin.models.store');
        Route::get('/models/{id}', [ModelController::class, 'show'])->name('api.admin.models.show');
        Route::put('/models/{id}', [ModelController::class, 'update'])->name('api.admin.models.update');
        Route::delete('/models/{id}', [ModelController::class, 'destroy'])->name('api.admin.models.destroy');
        Route::patch('/models/{id}/toggle', [ModelController::class, 'toggleStatus'])->name('api.admin.models.toggle');
        Route::post('/models/{id}/health-check', [ModelController::class, 'healthCheck'])->name('api.admin.models.health');
        Route::post('/models/{id}/test', [ModelController::class, 'testPrediction'])->name('api.admin.models.test');
        
        // Access requests
        Route::get('/access-requests', [AccessRequestController::class, 'index'])->name('api.admin.access-requests.index');
        Route::post('/access-requests/{id}/approve', [AccessRequestController::class, 'approve'])->name('api.admin.access-requests.approve');
        Route::post('/access-requests/{id}/reject', [AccessRequestController::class, 'reject'])->name('api.admin.access-requests.reject');
        Route::delete('/access-requests/{id}', [AccessRequestController::class, 'destroy'])->name('api.admin.access-requests.destroy');

        // Research news. `update` is POST, not PUT: a photo arrives as
        // multipart and PHP does not populate $_FILES for PUT.
        Route::get('/news', [NewsController::class, 'adminIndex'])->name('api.admin.news.index');
        Route::post('/news', [NewsController::class, 'store'])->name('api.admin.news.store');
        Route::get('/news/{id}', [NewsController::class, 'show'])->name('api.admin.news.show');
        Route::post('/news/{id}', [NewsController::class, 'update'])->name('api.admin.news.update');
        Route::patch('/news/{id}/toggle', [NewsController::class, 'toggle'])->name('api.admin.news.toggle');
        Route::delete('/news/{id}', [NewsController::class, 'destroy'])->name('api.admin.news.destroy');

        // Support tickets
        Route::get('/support/tickets', [SupportTicketController::class, 'adminIndex'])->name('api.admin.support.index');
        Route::patch('/support/tickets/{id}', [SupportTicketController::class, 'updateStatus'])->name('api.admin.support.update');
        Route::delete('/support/tickets/{id}', [SupportTicketController::class, 'destroy'])->name('api.admin.support.destroy');

        // Activity logs
        Route::get('/activities', [UserActivityController::class, 'index'])->name('api.admin.activities.index');
        Route::get('/activities/types', [UserActivityController::class, 'getTypes'])->name('api.admin.activities.types');
        Route::get('/users/{id}/activities', [UserActivityController::class, 'userActivities'])->name('api.admin.activities.user');
    });
    
    // In-app IT support. Scoped to the caller inside the controller; an
    // administrator sees every ticket through the /admin routes instead.
    Route::prefix('support')->group(function () {
        Route::get('/tickets', [SupportTicketController::class, 'index'])->name('api.support.tickets.index');
        Route::post('/tickets', [SupportTicketController::class, 'store'])->name('api.support.tickets.store');
        Route::get('/tickets/{id}', [SupportTicketController::class, 'show'])->name('api.support.tickets.show');
        Route::post('/tickets/{id}/reply', [SupportTicketController::class, 'reply'])->name('api.support.tickets.reply');
    });

    // Prediction pipeline (FASE 3). Every action is scoped to the caller in
    // AnalysisController, so these are open to any authenticated role.
    Route::prefix('predictions')->group(function () {
        // Chunked upload. Declared before the /{id} routes so "uploads" is
        // never swallowed as a prediction id.
        Route::post('/uploads', [PredictionUploadController::class, 'start'])->name('api.predictions.uploads.start');
        Route::get('/uploads/{uploadId}', [PredictionUploadController::class, 'status'])->name('api.predictions.uploads.status');
        Route::patch('/uploads/{uploadId}', [PredictionUploadController::class, 'chunk'])->name('api.predictions.uploads.chunk');
        Route::post('/uploads/{uploadId}/finalize', [PredictionUploadController::class, 'finalize'])->name('api.predictions.uploads.finalize');
        Route::delete('/uploads/{uploadId}', [PredictionUploadController::class, 'abort'])->name('api.predictions.uploads.abort');

        Route::get('/', [AnalysisController::class, 'index'])->name('api.predictions.index');
        Route::post('/', [AnalysisController::class, 'store'])->name('api.predictions.store');
        Route::get('/{id}', [AnalysisController::class, 'show'])->name('api.predictions.show');
        Route::delete('/{id}', [AnalysisController::class, 'destroy'])->name('api.predictions.destroy');
        Route::get('/{id}/frames', [AnalysisController::class, 'frames'])->name('api.predictions.frames');
        Route::get('/{id}/frames/{name}/preview', [AnalysisController::class, 'framePreview'])->name('api.predictions.frames.preview');
        Route::get('/{id}/download/results', [AnalysisController::class, 'downloadResults'])->name('api.predictions.download.results');
        Route::get('/{id}/download/complete', [AnalysisController::class, 'downloadComplete'])->name('api.predictions.download.complete');
    });
});
