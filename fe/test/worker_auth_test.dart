import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/model_info.dart';

/// The client half of the worker credential.
///
/// It never holds the secret — the registry does not return one — so what is
/// tested here is that the client reads the two flags it *is* told, and
/// defaults them the way the server does.
void main() {
  Map<String, dynamic> payload([Map<String, dynamic> extra = const {}]) => {
    'id': 3,
    'name': 'Workstation',
    'version': 'v1',
    'endpoint_url': 'https://lab.internal/predict',
    'status': 'online',
    'is_active': true,
    ...extra,
  };

  group('ModelInfo worker security', () {
    test('reads whether a secret is registered', () {
      final protected = ModelInfo.fromJson(payload({'has_auth_token': true}));
      final open = ModelInfo.fromJson(payload({'has_auth_token': false}));

      expect(protected.hasAuthToken, isTrue);
      expect(open.hasAuthToken, isFalse);
    });

    test('the secret itself is never part of the payload to read', () {
      // Belt to the server's braces. If `auth_token` ever reappeared in a
      // response, nothing on this side would carry it into the app.
      final model = ModelInfo.fromJson(
        payload({'has_auth_token': true, 'auth_token': 'leaked-somehow'}),
      );

      expect(model.hasAuthToken, isTrue);
      expect(
        model.toString().contains('leaked-somehow'),
        isFalse,
        reason: 'nothing on the client should be able to hold the secret',
      );
    });

    test('reads the TLS setting', () {
      expect(ModelInfo.fromJson(payload({'verify_tls': true})).verifyTls, isTrue);
      expect(ModelInfo.fromJson(payload({'verify_tls': false})).verifyTls, isFalse);
    });

    test('a payload from an older server reads as unprotected, not broken', () {
      // Every worker registered before this existed answers without either
      // field, and the registry screen still has to draw them.
      final model = ModelInfo.fromJson(payload());

      expect(model.hasAuthToken, isFalse);
      expect(model.verifyTls, isFalse);
      expect(model.name, 'Workstation');
    });

    test('MySQL integer booleans are understood', () {
      // PDO hands back 1 and 0 rather than true and false.
      final model = ModelInfo.fromJson(
        payload({'has_auth_token': 1, 'verify_tls': 1}),
      );

      expect(model.hasAuthToken, isTrue);
      expect(model.verifyTls, isTrue);
    });
  });
}
