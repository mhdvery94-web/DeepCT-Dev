<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Services\QueueBoard;
use App\Services\QueueHealth;

/**
 * Who is using the model right now, and who is waiting behind them.
 *
 * Admin only. Before this, the only way to answer "whose job is the GPU on"
 * was to read the activity log and work out which "started an analysis" had no
 * completion after it — which is guesswork, and wrong the moment two runs
 * overlap. See [QueueBoard] for why the records rather than the log.
 *
 * Deliberately live state, not history. "Who has ever used this model" is a
 * different question with a different answer already available in the
 * prediction history and the audit trail, and folding both into one list would
 * make the urgent one harder to read.
 */
class AdminQueueController extends Controller
{
    public function index(QueueBoard $board, QueueHealth $health)
    {
        $state = $health->inspect();

        return response()->json([
            'success' => true,
            'data' => $board->board(),

            // A long queue and a dead worker look identical from a list of
            // waiting jobs, and they call for opposite responses: one is
            // patience, the other is `npm run serve:all`. This is the
            // administrator's screen, so it gets the message with the command
            // in it.
            'meta' => $state + [
                'queue_message' => $health->message($state),
            ],
        ]);
    }
}
