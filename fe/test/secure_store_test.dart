import 'package:flutter_test/flutter_test.dart';

import 'package:fe/services/secure_store.dart';

void main() {
  tearDown(SecureStore.resetForTests);

  test('a working store reads and writes what it was given', () async {
    final saved = <String, String>{};

    SecureStore.debugRead = (key) async => saved[key];
    SecureStore.debugWrite = (key, value) async => saved[key] = value;

    await SecureStore.write('token', 'abc');

    expect(await SecureStore.read('token'), 'abc');
  });

  test('a read that throws answers null instead of taking the request down', () async {
    // On Android the plugin keeps its data in EncryptedSharedPreferences, and
    // installing a differently-built APK over an existing one leaves data the
    // new key cannot decrypt. That read runs on *every* request, so an
    // exception here took down public endpoints that need no token at all.
    SecureStore.debugRead = (key) async => throw Exception('keystore mismatch');

    expect(await SecureStore.read('token'), isNull);
  });

  test('a failed read wipes the store so the next one can succeed', () async {
    var wiped = false;

    SecureStore.debugRead = (key) async => throw Exception('keystore mismatch');
    SecureStore.debugDeleteAll = () async => wiped = true;

    await SecureStore.read('token');

    expect(
      wiped,
      isTrue,
      reason: 'unreadable data has to go, or it fails forever',
    );
  });

  test('a write that throws does not fail the sign-in that earned it', () async {
    // The token was issued; failing to cache it should cost this session, not
    // the login. Reporting "an unexpected error occurred" after a successful
    // 200 is how a working sign-in looked broken.
    SecureStore.debugWrite = (key, value) async => throw Exception('keystore');

    await expectLater(SecureStore.write('token', 'abc'), completes);
  });

  test('a delete that throws is not worth failing a sign-out over', () async {
    SecureStore.debugDelete = (key) async => throw Exception('keystore');

    await expectLater(SecureStore.delete('token'), completes);
  });
}
