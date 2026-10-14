import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/services/model_upload_service.dart';
import 'package:fe/widgets/model_upload_dialog.dart';
import 'package:fe/widgets/app_dialog.dart';

class SessionService extends ModelUploadService {
  SessionService({ModelControl? control})
    : super(control: control ?? ((_, _, _) async => session));
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
  Future<List<Map<String, dynamic>>> list({
    int page = 1,
    String search = '',
  }) async {
    lastPage = 3;
    return lists++ == 0 ? [session] : [];
  }
}

class PagedSessionService extends SessionService {
  PagedSessionService({super.control});
  final pages = <int>[];
  @override
  Future<List<Map<String, dynamic>>> list({
    int page = 1,
    String search = '',
  }) async {
    pages.add(page);
    lastPage = 3;
    return page == 3 || search.isNotEmpty
        ? [
            {...SessionService.session, 'state': 'active'},
            {...SessionService.session, 'id': 2},
          ]
        : [
            {...SessionService.session, 'id': 101 + page},
          ];
  }
}

void main() {
  testWidgets('delayed A cannot replace B or New selection', (tester) async {
    final replies = <int, Completer<Map<String, dynamic>>>{};
    final service = SessionService(
      control: (path, _, _) {
        final id = int.parse(path.split('/').last);
        return (replies[id] = Completer<Map<String, dynamic>>()).future;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ModelUploadDialog(service: service),
          ),
        ),
      ),
    );
    await tester.pump();
    void select(int? id) => tester
        .widget<DropdownButtonFormField<int>>(
          find.byType(DropdownButtonFormField<int>),
        )
        .onChanged!(id);
    select(1);
    await tester.pump();
    select(2);
    await tester.pump();
    replies[2]!.complete({
      ...SessionService.session,
      'id': 2,
      'state': 'active',
    });
    await tester.pump();
    replies[1]!.complete(SessionService.session);
    await tester.pump();
    expect(find.text('Nonaktifkan versi'), findsOneWidget);
    expect(find.text('Aktifkan versi'), findsNothing);
    select(1);
    await tester.pump();
    select(null);
    await tester.pump();
    replies[1]!.complete(SessionService.session);
    await tester.pump();
    expect(find.text('Aktifkan versi'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('saved session pages expose older management versions', (
    tester,
  ) async {
    final actions = <String>[];
    final service = PagedSessionService(
      control: (path, method, _) async {
        if (method == 'POST') actions.add(path);
        return {
          ...SessionService.session,
          'id': path.contains('/2') ? 2 : 1,
          'state': path.endsWith('/1') ? 'active' : 'ready_for_activate',
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ModelUploadDialog(service: service),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Sesi berikutnya'));
    await tester.pump();
    await tester.tap(find.text('Sesi berikutnya'));
    await tester.pump();
    expect(service.pages, [1, 2, 3]);
    expect(find.text('Halaman 3 / 3'), findsOneWidget);
    tester
        .widget<DropdownButtonFormField<int>>(
          find.byType(DropdownButtonFormField<int>),
        )
        .onChanged!(1);
    await tester.pump();
    await tester.ensureVisible(find.text('Nonaktifkan versi'));
    await tester.tap(find.text('Nonaktifkan versi'));
    await tester.pump();
    tester
        .widget<DropdownButtonFormField<int>>(
          find.byType(DropdownButtonFormField<int>),
        )
        .onChanged!(2);
    await tester.pump();
    await tester.ensureVisible(find.text('Aktifkan versi'));
    await tester.tap(find.text('Aktifkan versi'));
    await tester.pump();
    expect(actions, [
      '/admin/model-uploads/1/deactivate',
      '/admin/model-uploads/2/activate',
    ]);
    expect(find.text('Cari sesi model / versi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
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
