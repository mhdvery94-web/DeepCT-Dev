import 'package:flutter_test/flutter_test.dart';

import 'package:fe/services/auth_provider.dart';

void main() {
  test('a shape this build cannot read says so, and says what to do', () {
    // What a stale APK hits: the server stopped sending a field the old
    // UserModel read into a non-nullable String, so parsing a *successful*
    // login throws. "An unexpected error occurred" sent someone hunting
    // through the backend, the tunnel and the database for an hour when the
    // answer was to install a newer build.
    final error = TypeError();

    final message = loginFailureMessage(error);

    expect(message, contains('cannot read'));
    expect(message.toLowerCase(), contains('latest'));
  });

  test('anything else keeps the old wording', () {
    // Only the case we can actually name gets a named message. Guessing at
    // the rest would trade one misleading sentence for another.
    expect(
      loginFailureMessage(StateError('something else entirely')),
      'An unexpected error occurred',
    );
  });
}
