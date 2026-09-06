import 'package:flutter_test/flutter_test.dart';

import 'package:fe/services/admin_queue_service.dart';

/// The administrator's live queue board.
///
/// The screen itself needs a network client, so what is pinned here is the
/// layer under it: the parsing that turns the endpoint's answer into the rows
/// the screen draws. Every assertion below is about a distinction the screen
/// relies on and would silently lose — a running job that is not numbered, a
/// deregistered model, a stalled worker.
void main() {
  Map<String, dynamic> body({
    List<Map<String, dynamic>> running = const [],
    List<Map<String, dynamic>> waiting = const [],
    int minutesPerJob = 2,
    bool stalled = false,
    String? queueMessage,
  }) => {
    'success': true,
    'data': {
      'running': running,
      'waiting': waiting,
      'minutes_per_job': minutesPerJob,
      'busy': running.length,
      'queued': waiting.length,
    },
    'meta': {
      'stalled': stalled,
      'waiting': waiting.length,
      'oldest_wait_seconds': 0,
      'queue_message': queueMessage,
    },
  };

  Map<String, dynamic> row({
    required int id,
    required String status,
    String? userName = 'Fajri',
    String? userEmail = 'fajri@brin.go.id',
    Map<String, dynamic>? model = const {'name': 'deepCT', 'version': 'v1.0'},
    int frames = 12,
    int elapsed = 90,
    int? position,
    int? wait,
  }) => {
    'id': id,
    'job_id': 'job-$id',
    'status': status,
    'user': userName == null
        ? null
        : {'id': 2, 'name': userName, 'email': userEmail},
    'model': model,
    'input_files_count': frames,
    'elapsed_seconds': elapsed,
    'queue_position': position,
    'estimated_wait_minutes': wait,
  };

  test('an empty board is empty, not a queue of nothing', () {
    final board = QueueBoard.fromJson(body());

    expect(board.isEmpty, isTrue);
    expect(board.running, isEmpty);
    expect(board.waiting, isEmpty);
  });

  test('the running job names who it belongs to', () {
    // The whole point of the screen: an administrator should not have to infer
    // whose work the GPU is on from an audit trail.
    final board = QueueBoard.fromJson(
      body(running: [row(id: 7, status: 'processing')]),
    );

    final job = board.running.single;

    expect(job.isRunning, isTrue);
    expect(job.who, 'Fajri');
    expect(job.userEmail, 'fajri@brin.go.id');
    expect(job.model, 'deepCT v1.0');
    expect(job.inputFilesCount, 12);
  });

  test('a running job carries no queue position', () {
    // It is not waiting for anything. Numbering it alongside the line would
    // say it is still in it.
    final board = QueueBoard.fromJson(
      body(running: [row(id: 7, status: 'processing')]),
    );

    expect(board.running.single.queuePosition, isNull);
    expect(board.running.single.estimatedWaitMinutes, isNull);
  });

  test('waiting jobs keep the order and the numbers the server gave them', () {
    final board = QueueBoard.fromJson(
      body(
        waiting: [
          row(id: 8, status: 'pending', position: 1, wait: 2),
          row(id: 9, status: 'pending', position: 2, wait: 4),
        ],
      ),
    );

    expect(board.waiting.map((e) => e.id).toList(), [8, 9]);
    expect(board.waiting.map((e) => e.queuePosition).toList(), [1, 2]);
    expect(board.waiting.map((e) => e.estimatedWaitMinutes).toList(), [2, 4]);
  });

  test('a deregistered model reads as removed rather than blank', () {
    // `model_id` is `set null`, so this genuinely occurs, and an empty space
    // on the row would read as a rendering fault.
    final board = QueueBoard.fromJson(
      body(running: [row(id: 7, status: 'processing', model: null)]),
    );

    expect(board.running.single.model, 'Model removed');
  });

  test('a run whose owner is gone still says so', () {
    final board = QueueBoard.fromJson(
      body(running: [row(id: 7, status: 'processing', userName: null)]),
    );

    expect(board.running.single.who, 'Deleted account');
  });

  test('elapsed time is read at a glance', () {
    QueueEntry at(int seconds) => QueueEntry.fromJson(
      row(id: 1, status: 'pending', elapsed: seconds),
    );

    expect(at(30).elapsedLabel, 'just now');
    expect(at(240).elapsedLabel, '4m');
    expect(at(3600).elapsedLabel, '1h');
    expect(at(4320).elapsedLabel, '1h 12m');
  });

  test('a stalled queue is told apart from a long one', () {
    // Four jobs waiting means patience. Four jobs waiting with nothing
    // consuming them means `npm run serve:all`, and the two look identical
    // from the list alone.
    final busy = QueueBoard.fromJson(
      body(waiting: [row(id: 8, status: 'pending', position: 1)]),
    );
    expect(busy.stalled, isFalse);
    expect(busy.queueMessage, isNull);

    final dead = QueueBoard.fromJson(
      body(
        waiting: [row(id: 8, status: 'pending', position: 1)],
        stalled: true,
        queueMessage: 'Nothing has picked this job up for 9 minute(s).',
      ),
    );
    expect(dead.stalled, isTrue);
    expect(dead.queueMessage, contains('9 minute'));
  });

  test('the per-run average travels with the board', () {
    // Every estimate on the screen is built from it, so the screen shows its
    // own working rather than producing numbers from nowhere.
    final board = QueueBoard.fromJson(body(minutesPerJob: 3));

    expect(board.minutesPerJob, 3);
  });
}
