import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/services/model_upload_service.dart';
import 'package:fe/widgets/model_upload_dialog.dart';
import 'package:fe/widgets/app_dialog.dart';

class SessionService extends ModelUploadService {
  SessionService() : super(control: (_, _, _) async => session);
  static final session = <String, dynamic>{
    'id': 1,
    'state': 'ready_for_activate',
    'published': true,
    'offset': 100,
    'manifest': {
      'model_id': 'fixture',
      'version': '1.0.0',
      'name': 'Fixture',
      'description': '',
    },
  };
  int lists = 0;
  @override
  Future<List<Map<String, dynamic>>> list() async =>
      lists++ == 0 ? [session] : [];
}

void main() {
  for (final size in [const Size(375, 667), const Size(667, 375)]) {
    testWidgets(
      'upload controls fit $size with large text and remain explicit',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    showAppDialog<void>(
                      context: context,
                      maxWidth: 640,
                      builder: (_) =>
                          ModelUploadDialog(service: SessionService()),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Upload bobot model ke TUF'), findsOneWidget);
        expect(find.text('Sinkronisasi katalog TUF'), findsOneWidget);
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byType(DropdownButtonFormField<int>),
            )
            .onChanged!(1);
        await tester.pumpAndSettle();
        expect(find.text('Aktifkan versi'), findsOneWidget);
        expect(find.text('Publikasikan nonaktif'), findsNothing);
        expect(find.textContaining('bukan validasi ilmiah'), findsOneWidget);
        await tester.ensureVisible(find.text('Aktifkan versi'));
        await tester.tap(find.text('Aktifkan versi'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
