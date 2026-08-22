import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/model_status_message.dart';

void main() {
  test('a dead tunnel reads as a disconnected server, not as ngrok', () {
    final message = modelStatusMessage('tunnel_down');

    expect(message, contains('disconnected'));
    expect(message.toLowerCase(), isNot(contains('tunnel')));
    expect(message.toLowerCase(), isNot(contains('ngrok')));
  });

  test('a model never configured is not described as a dead server', () {
    // Telling someone to restart something that was never set up sends them
    // looking for a machine that does not exist.
    final message = modelStatusMessage('no_endpoint');

    expect(message, contains('no server address'));
    expect(message, isNot(contains('not responding')));
  });

  test('a slow worker says the job will take longer, not that it failed', () {
    final message = modelStatusMessage('slow');

    expect(message, contains('slowly'));
    expect(message, contains('longer'));
  });

  test('an unreachable worker asks for an administrator', () {
    expect(modelStatusMessage('unreachable'), contains('not responding'));
  });

  test('a row written before the reason column existed still reads sensibly', () {
    // Every model row has a null reason until the next health check writes
    // one, which is at most a minute after the migration runs.
    expect(modelStatusMessage(null), contains('not responding'));
    expect(modelStatusMessage('something_new'), contains('not responding'));
  });

  test('no message names an HTTP status code or an error identifier', () {
    for (final reason in [
      'tunnel_down',
      'no_endpoint',
      'slow',
      'unreachable',
      null,
    ]) {
      expect(
        modelStatusMessage(reason),
        isNot(matches(RegExp(r'HTTP \d|ERR_|\d{3,}'))),
        reason: 'reason "$reason" leaked machine detail',
      );
    }
  });

  test('a slow worker is labelled SLOW, not TROUBLE', () {
    // The badge rendered status.toUpperCase(), so a worker answering slowly
    // read "TROUBLE" right beside a sentence saying "answering slowly" —
    // the same shape of jargon part A removed from the copy.
    expect(modelStatusLabel('trouble'), 'SLOW');
  });

  test('the other two statuses keep the words people already know', () {
    expect(modelStatusLabel('online'), 'ONLINE');
    expect(modelStatusLabel('offline'), 'OFFLINE');
  });

  test('an unknown status is shown as given rather than hidden', () {
    // A status this build has not heard of is worth seeing, not swallowing.
    expect(modelStatusLabel('quarantined'), 'QUARANTINED');
  });
}
