import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fe/models/user_model.dart';
import 'package:fe/screens/auth/password_gate.dart';
import 'package:fe/services/auth_provider.dart';

/// An AuthProvider holding a user, without going near the network.
class _FakeAuth extends AuthProvider {
  _FakeAuth(this._fake);

  UserModel? _fake;

  @override
  UserModel? get user => _fake;

  @override
  void clearMustChangePassword() {
    final current = _fake;
    if (current == null) return;
    _fake = current.withPasswordChanged();
    notifyListeners();
  }
}

UserModel _user({required bool mustChange}) => UserModel(
  id: 2,
  name: 'Dr Sample Researcher',
  email: 'researcher@brin.go.id',
  role: 'user',
  isActive: true,
  mustChangePassword: mustChange,
);

Widget _host(AuthProvider auth) => ChangeNotifierProvider<AuthProvider>.value(
  value: auth,
  child: const MaterialApp(
    home: PasswordGate(child: Scaffold(body: Text('THE CONSOLE'))),
  ),
);

void main() {
  testWidgets('lets a normal account straight through', (tester) async {
    await tester.pumpWidget(_host(_FakeAuth(_user(mustChange: false))));

    expect(find.text('THE CONSOLE'), findsOneWidget);
  });

  testWidgets('blocks an account still on its default password', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_FakeAuth(_user(mustChange: true))));

    expect(find.text('THE CONSOLE'), findsNothing);
    expect(find.text('Choose your password'), findsOneWidget);
  });

  testWidgets('offers signing out rather than trapping the account', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_FakeAuth(_user(mustChange: true))));

    expect(find.text('SIGN OUT INSTEAD'), findsOneWidget);
  });

  testWidgets('has no cancel button — the step is not optional', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_FakeAuth(_user(mustChange: true))));

    expect(find.text('CANCEL'), findsNothing);
    expect(find.text('SET PASSWORD'), findsOneWidget);
  });

  testWidgets('shows the console once the flag clears', (tester) async {
    final auth = _FakeAuth(_user(mustChange: true));
    await tester.pumpWidget(_host(auth));

    expect(find.text('THE CONSOLE'), findsNothing);

    auth.clearMustChangePassword();
    await tester.pumpAndSettle();

    expect(find.text('THE CONSOLE'), findsOneWidget);
  });

  testWidgets('a signed-out visitor is not held here', (tester) async {
    // No user at all means the gate has nothing to enforce; the tree behind it
    // decides what to show.
    await tester.pumpWidget(_host(_FakeAuth(null)));

    expect(find.text('THE CONSOLE'), findsOneWidget);
  });
}
