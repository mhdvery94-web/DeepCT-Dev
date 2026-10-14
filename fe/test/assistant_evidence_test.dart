import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/widgets/assistant_evidence.dart';

void main() {
  testWidgets(
    'historical snapshot unavailable is explicit without current metadata',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssistantEvidence(
                request: {
                  'sources': [
                    {
                      'id': 1,
                      'status': 'completed',
                      'model': {
                        'id': 7,
                        'provenance': 'historical_model_snapshot_unavailable',
                      },
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sumber dan metrik tepercaya'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Versi historis / provenans model tidak tersedia'),
        findsOneWidget,
      );
      expect(find.textContaining('null · null'), findsNothing);
    },
  );
}
