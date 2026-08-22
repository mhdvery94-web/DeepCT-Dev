import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape both dashboards use for their recent-activity list.
///
/// Reproduced here rather than driving the real screens, which each fetch
/// four endpoints on `initState`. What is being pinned is the layout
/// decision, and it can be wrong in two opposite directions — so both are
/// tested.
Widget activityBox(int rows) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: rows,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  SizedBox(height: 72, child: Text('row $index')),
            ),
          ),
          const Text('below the list'),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('a long list is capped and scrolls inside its own box', (
    tester,
  ) async {
    await tester.pumpWidget(activityBox(20));
    await tester.pumpAndSettle();

    final box = tester.getSize(find.byType(ListView));
    expect(box.height, lessThanOrEqualTo(320));

    // The whole point: what follows the list is reachable without scrolling
    // past twenty rows first.
    expect(find.text('below the list'), findsOneWidget);
  });

  testWidgets('a short list does not pad itself out to the cap', (
    tester,
  ) async {
    // This is the case that catches `shrinkWrap` being dropped along with
    // `NeverScrollableScrollPhysics`. A bounded ListView without shrinkWrap
    // fills all 320px whether it holds two rows or twenty.
    await tester.pumpWidget(activityBox(2));
    await tester.pumpAndSettle();

    final box = tester.getSize(find.byType(ListView));
    expect(box.height, lessThan(200));
  });
}
