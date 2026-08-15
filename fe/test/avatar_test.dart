import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/user_model.dart';
import 'package:fe/widgets/user_avatar.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

UserModel _user({String? avatar}) => UserModel(
  id: 3,
  username: 'dyanna',
  name: 'Dyanna Basia',
  email: 'dyanna@brin.go.id',
  role: 'user',
  isActive: true,
  avatarPath: avatar,
);

void main() {
  group('UserModel', () {
    test('reads avatar_url from the payload', () {
      final user = UserModel.fromJson(const {
        'id': 3,
        'username': 'dyanna',
        'name': 'Dyanna Basia',
        'email': 'dyanna@brin.go.id',
        'role': 'user',
        'is_active': true,
        'avatar_url': '/users/3/avatar',
      });

      expect(user.avatarPath, '/users/3/avatar');
      expect(user.hasAvatar, isTrue);
    });

    test('an account with no photo reports none', () {
      final user = UserModel.fromJson(const {
        'id': 3,
        'username': 'dyanna',
        'name': 'Dyanna Basia',
        'email': 'dyanna@brin.go.id',
        'role': 'user',
        'is_active': true,
        'avatar_url': null,
      });

      expect(user.avatarPath, isNull);
      expect(user.hasAvatar, isFalse);
    });

    test('withAvatarPath keeps everything else', () {
      final updated = _user().withAvatarPath('/users/3/avatar');

      expect(updated.avatarPath, '/users/3/avatar');
      expect(updated.id, 3);
      expect(updated.username, 'dyanna');
      expect(updated.role, 'user');
      expect(updated.isActive, isTrue);
    });

    test('withAvatarPath(null) clears the photo', () {
      final cleared = _user(avatar: '/users/3/avatar').withAvatarPath(null);

      expect(cleared.hasAvatar, isFalse);
    });
  });

  group('UserAvatar without a photo', () {
    testWidgets('draws initials from a two-part name', (tester) async {
      await tester.pumpWidget(
        _host(const UserAvatar(avatarPath: null, name: 'Dyanna Basia')),
      );

      expect(find.text('DB'), findsOneWidget);
    });

    testWidgets('uses the first two letters of a single name', (tester) async {
      await tester.pumpWidget(
        _host(const UserAvatar(avatarPath: null, name: 'admin')),
      );

      expect(find.text('AD'), findsOneWidget);
    });

    testWidgets('takes the first and last of three names', (tester) async {
      await tester.pumpWidget(
        _host(const UserAvatar(avatarPath: null, name: 'Fajri Very Rahman')),
      );

      expect(find.text('FR'), findsOneWidget);
    });

    testWidgets('survives a single letter', (tester) async {
      await tester.pumpWidget(
        _host(const UserAvatar(avatarPath: null, name: 'A')),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('falls back to a question mark for an empty name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const UserAvatar(avatarPath: null, name: '   ')),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('honours the requested size', (tester) async {
      await tester.pumpWidget(
        _host(const UserAvatar(avatarPath: null, name: 'Dyanna', size: 84)),
      );

      expect(
        tester.getSize(find.byType(UserAvatar)),
        const Size(84, 84),
      );
    });

    testWidgets('gives the same person the same colour every time', (
      tester,
    ) async {
      // The tile colour is derived from the name, so a face keeps its colour
      // between sessions instead of shuffling on every load.
      Color tintOf(WidgetTester t) =>
          (t.widget<Text>(find.text('DB')).style!.color)!;

      await tester.pumpWidget(
        _host(const UserAvatar(avatarPath: null, name: 'Dyanna Basia')),
      );
      final first = tintOf(tester);

      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(
        _host(const UserAvatar(avatarPath: null, name: 'Dyanna Basia')),
      );

      expect(tintOf(tester), first);
    });
  });
}
