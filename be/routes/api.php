<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AccessRequestController;
use App\Http\Controllers\API\AnalysisController;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\AvatarController;
use App\Http\Controllers\API\MeController;
use App\Http\Controllers\API\MeTrainingController;
use App\Http\Controllers\API\MessageController;
use App\Http\Controllers\API\NewsController;
use App\Http\Controllers\API\TrainingController;
use App\Http\Controllers\API\TrainingWorkerController;
use App\Http\Controllers\API\NotificationController;
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

// Requests for an account, from the public landing page. Rate limited the
// same way login is: it is the other unauthenticated write path.
Route::post('/access-requests', [AccessRequestController::class, 'store'])
    ->middleware('throttle:5,1')
    ->name('api.access-requests.store');

// A message from the sign-in page, for people who cannot get in — the third
// and last unauthenticated write path.
//
// 5 per 10 minutes, not 5 per hour. The hourly window was picked to be tight
// against spam and turned out to be tight against *people*: someone testing
// the form, or writing again because they forgot a detail, hit "Too many
// attempts" and had no way to tell it apart from a broken button. A ten-minute
// window still bounds abuse, and forgives a real person within one coffee.
Route::post('/messages/public', [MessageController::class, 'storePublic'])
    ->middleware('throttle:5,10')
    ->name('api.messages.public');

// Research news for the landing page slideshow. Read-only and published-only;
// the image route serves a draft to an administrator, which is why it resolves
// the token itself rather than sitting behind auth middleware.
Route::get('/news', [NewsController::class, 'index'])->name('api.news.index');
Route::get('/news/{id}/image', [NewsController::class, 'image'])->name('api.news.image');

// GPU training workers. Outside `auth:sanctum` on purpose: a worker is a
// machine with a long-lived shared secret, not a person with an account, and
// it must not be able to reach anything but these six routes. See
// EnsureTrainingWorker and ARCHITECTURE.md 7.
Route::middleware('training.worker')->prefix('training/worker')->group(function () {
    Route::post('/claim', [TrainingWorkerController::class, 'claim'])->name('api.training.worker.claim');
    Route::get('/jobs/{id}/dataset', [TrainingWorkerController::class, 'dataset'])->name('api.training.worker.dataset');
    Route::post('/jobs/{id}/heartbeat', [TrainingWorkerController::class, 'heartbeat'])->name('api.training.worker.heartbeat');
    Route::post('/jobs/{id}/checkpoint', [TrainingWorkerController::class, 'checkpoint'])->name('api.training.worker.checkpoint');
    Route::post('/jobs/{id}/complete', [TrainingWorkerController::class, 'complete'])->name('api.training.worker.complete');
    Route::post('/jobs/{id}/fail', [TrainingWorkerController::class, 'fail'])->name('api.training.worker.fail');
});

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

        // The refresh button in the upload screen. It probes the endpoints
        // rather than re-reading what the scheduler last wrote, because the
        // person pressing it is about to upload and wants to know *now*.
        // Throttled: it is the one route where an ordinary user causes an
        // outbound request, and a held button should not become a fan-out.
        Route::post('/models/refresh', [MeController::class, 'refreshModels'])
            ->middleware('throttle:10,1')
            ->name('api.me.models.refresh');

        // Own profile photo.
        Route::post('/avatar', [AvatarController::class, 'updateOwn'])->name('api.me.avatar.update');
        Route::delete('/avatar', [AvatarController::class, 'destroyOwn'])->name('api.me.avatar.destroy');

        // Own password. Without this the only way to change one is an admin
        // reset to the shared default, which every admin then knows.
        Route::post('/password', [AuthController::class, 'changePassword'])->name('api.me.password');

        // Training, from the researcher's side. The same shape as prediction:
        // upload an archive, a job is queued, a remote GPU does the work. Only
        // the result differs — numbers rather than frames.
        Route::prefix('training')->group(function () {
            Route::get('/jobs', [MeTrainingController::class, 'index'])->name('api.me.training.jobs');
            Route::post('/jobs', [MeTrainingController::class, 'store'])->name('api.me.training.jobs.store');
            Route::get('/jobs/{id}', [MeTrainingController::class, 'show'])->name('api.me.training.jobs.show');
            Route::post('/jobs/{id}/cancel', [MeTrainingController::class, 'cancel'])->name('api.me.training.jobs.cancel');
        });
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

        // Managed model training. The platform records what should be trained
        // and what came back; the GPU lives on Kaggle and talks to the worker
        // routes below, outside this group.
        Route::get('/training/datasets', [TrainingController::class, 'datasets'])->name('api.admin.training.datasets');
        Route::post('/training/datasets', [TrainingController::class, 'storeDataset'])->name('api.admin.training.datasets.store');
        Route::delete('/training/datasets/{id}', [TrainingController::class, 'destroyDataset'])->name('api.admin.training.datasets.destroy');

        // No `POST /training/jobs`. Starting a run belongs to the researcher
        // who has the data — see `me/training/jobs`. An administrator keeps
        // oversight of every run here: see them, push them, cancel them,
        // delete them. Two ways to start one, differing only in whose name it
        // carries, is not oversight.
        Route::get('/training/jobs', [TrainingController::class, 'jobs'])->name('api.admin.training.jobs');
        Route::get('/training/jobs/{id}', [TrainingController::class, 'showJob'])->name('api.admin.training.jobs.show');
        Route::post('/training/jobs/{id}/dispatch', [TrainingController::class, 'dispatchJob'])->name('api.admin.training.jobs.dispatch');
        Route::post('/training/jobs/{id}/cancel', [TrainingController::class, 'cancelJob'])->name('api.admin.training.jobs.cancel');
        Route::delete('/training/jobs/{id}', [TrainingController::class, 'destroyJob'])->name('api.admin.training.jobs.destroy');
        Route::get('/training/jobs/{id}/weights', [TrainingController::class, 'downloadWeights'])->name('api.admin.training.jobs.weights');
        Route::post('/training/jobs/{id}/register-model', [TrainingController::class, 'registerModel'])->name('api.admin.training.jobs.register');

        // Support conversations
        Route::get('/conversations', [MessageController::class, 'adminIndex'])->name('api.admin.conversations.index');
        Route::get('/conversations/{id}', [MessageController::class, 'adminShow'])->name('api.admin.conversations.show');
        Route::post('/conversations/{id}/reply', [MessageController::class, 'adminReply'])->name('api.admin.conversations.reply');
        Route::post('/conversations/{id}/read', [MessageController::class, 'adminMarkRead'])->name('api.admin.conversations.read');
        Route::patch('/conversations/{id}', [MessageController::class, 'adminUpdate'])->name('api.admin.conversations.update');
        Route::delete('/conversations/{id}', [MessageController::class, 'adminDestroy'])->name('api.admin.conversations.destroy');

        // Activity logs
        Route::get('/activities', [UserActivityController::class, 'index'])->name('api.admin.activities.index');
        Route::get('/activities/types', [UserActivityController::class, 'getTypes'])->name('api.admin.activities.types');
        Route::get('/users/{id}/activities', [UserActivityController::class, 'userActivities'])->name('api.admin.activities.user');
    });
    
    // IT support, as messaging. A researcher has exactly one thread, so none
    // of these takes an id -- "my thread" is the only thing they can mean,
    // which removes any way to reach somebody else's.
    Route::get('/messages', [MessageController::class, 'index'])->name('api.messages.index');
    Route::post('/messages', [MessageController::class, 'store'])->name('api.messages.store');
    Route::post('/messages/read', [MessageController::class, 'markRead'])->name('api.messages.read');

    // The bell. Scoped through the notifiable relation, so there is no id here
    // that could reach another account's row either.
    Route::get('/notifications', [NotificationController::class, 'index'])->name('api.notifications.index');
    Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount'])->name('api.notifications.count');
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead'])->name('api.notifications.read-all');
    Route::post('/notifications/{id}/read', [NotificationController::class, 'markRead'])->name('api.notifications.read');
    Route::delete('/notifications/{id}', [NotificationController::class, 'destroy'])->name('api.notifications.destroy');
    Route::delete('/notifications', [NotificationController::class, 'clear'])->name('api.notifications.clear');

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
