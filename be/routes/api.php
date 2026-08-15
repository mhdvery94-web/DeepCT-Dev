<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AnalysisController;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\MeController;
use App\Http\Controllers\API\PredictionUploadController;
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
    });


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
        
        // Model management
        Route::get('/models', [ModelController::class, 'index'])->name('api.admin.models.index');
        Route::post('/models', [ModelController::class, 'store'])->name('api.admin.models.store');
        Route::get('/models/{id}', [ModelController::class, 'show'])->name('api.admin.models.show');
        Route::put('/models/{id}', [ModelController::class, 'update'])->name('api.admin.models.update');
        Route::delete('/models/{id}', [ModelController::class, 'destroy'])->name('api.admin.models.destroy');
        Route::patch('/models/{id}/toggle', [ModelController::class, 'toggleStatus'])->name('api.admin.models.toggle');
        Route::post('/models/{id}/health-check', [ModelController::class, 'healthCheck'])->name('api.admin.models.health');
        Route::post('/models/{id}/test', [ModelController::class, 'testPrediction'])->name('api.admin.models.test');
        
        // Activity logs
        Route::get('/activities', [UserActivityController::class, 'index'])->name('api.admin.activities.index');
        Route::get('/activities/types', [UserActivityController::class, 'getTypes'])->name('api.admin.activities.types');
        Route::get('/users/{id}/activities', [UserActivityController::class, 'userActivities'])->name('api.admin.activities.user');
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
        Route::get('/{id}/download/results', [AnalysisController::class, 'downloadResults'])->name('api.predictions.download.results');
        Route::get('/{id}/download/complete', [AnalysisController::class, 'downloadComplete'])->name('api.predictions.download.complete');
    });
});
