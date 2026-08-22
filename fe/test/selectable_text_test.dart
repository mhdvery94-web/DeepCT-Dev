import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/widgets/app_dialog.dart';

void main() {
  testWidgets('a dialog\'s text can be selected and copied', (tester) async {
    // The dialog needs its own SelectionArea: showDialog pushes a route into
    // the overlay, so it is not a descendant of whatever wraps the shell.
    // This is the one that gets missed.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAppDialog<void>(
                context: context,
                builder: (_) => const Text('a generated password'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('a generated password'),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
  });
}
