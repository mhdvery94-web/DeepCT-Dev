import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/screens/assistant/research_assistant_screen.dart';
import 'package:fe/services/ai_service.dart';
import 'package:fe/services/api_client.dart';

class FakeAi extends AiService {
  bool enabled = false;
  String state = 'completed';
  bool failSend = false;
  bool failPoll = false;
  ApiException? rejection;
  final List<Map<String, dynamic>> sends = [];
  int polls = 0;
  Map<String, dynamic> get request => {
    'id': 42,
    'conversation_id': 7,
    'user_message_id': 100,
    'status': state,
    'error_code': state == 'failed' ? 'provider_timeout' : null,
    'assistant_message': state == 'completed'
        ? {'id': 101, 'role': 'assistant', 'content': 'Jawaban eksperimen'}
        : null,
    'sources': [
      {
        'type': 'analysis_record',
        'id': 3,
        'status': 'pending',
        'processing_time_seconds': null,
        'metrics': {'mae': null},
      },
    ],
    'metrics': {'total_duration': 50000000000},
  };
  @override
  Future<Map<String, dynamic>> get(String path, {int page = 1}) async {
    if (path == 'status') {
      return {
        'enabled': enabled,
        'model': 'deepseek-r1:1.5b',
        'experimental': true,
        'limits': {},
      };
    }
    if (path == 'conversations') {
      return {
        'conversations': [
          {
            'id': page == 1 ? 7 : 8,
            'title': page == 1 ? 'Riwayat riset' : 'Percakapan lama',
          },
        ],
        'pagination': {'current_page': page, 'last_page': 2},
      };
    }
    if (path.startsWith('conversations/')) {
      return {
        'id': 7,
        'title': 'Riwayat riset',
        'messages': [
          {
            'id': page == 1 ? 100 : 90,
            'role': 'user',
            'content': page == 1 ? 'Pertanyaan tersimpan' : 'Pesan lama',
          },
          if (state == 'completed' && page == 1)
            {'id': 101, 'role': 'assistant', 'content': 'Jawaban eksperimen'},
        ],
        'pagination': {'current_page': page, 'last_page': 2},
        'request': request,
      };
    }
    polls++;
    if (failPoll) throw const ApiException('Jaringan polling terputus');
    return request;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    if (path == 'conversations') return {'id': 7, 'title': 'Percakapan baru'};
    if (path.endsWith('/cancel')) {
      state = 'cancelled';
      return request;
    }
    sends.add(Map.from(data));
    if (rejection != null) {
      final failure = rejection!;
      rejection = null;
      throw failure;
    }
    if (failSend) {
      failSend = false;
      throw const ApiException('Jaringan terputus');
    }
    state = 'queued';
    return {
      'request': request,
      'user_message': {'id': 100, 'role': 'user', 'content': data['content']},
    };
  }
}

Future<void> mount(WidgetTester tester, FakeAi api, {int? context}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ResearchAssistantScreen(service: api, analysisRecordId: context),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboardText;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  testWidgets('definitive admission refusal lets the user correct input', (
    tester,
  ) async {
    final api = FakeAi()
      ..enabled = true
      ..rejection = const ApiException(
        'Konteks tidak ditemukan',
        statusCode: 404,
      );
    await mount(tester, api, context: 3);
    await tester.enterText(find.byKey(const Key('ai-input')), 'Pertanyaan');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-send')));
    await tester.pumpAndSettle();
    expect(find.text('Konteks tidak ditemukan'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('ai-input'))).enabled,
      isTrue,
    );
    await tester.tap(find.text('Lepas konteks'));
    await tester.pump();
    expect(find.textContaining('Konteks prediksi'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('poll errors retry and disposal cancels future polls', (
    tester,
  ) async {
    final api = FakeAi()
      ..enabled = true
      ..state = 'processing'
      ..failPoll = true;
    await mount(tester, api);
    await tester.tap(find.text('Riwayat riset'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Jaringan polling terputus'), findsOneWidget);
    api.failPoll = false;
    await tester.tap(find.text('Coba polling lagi'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Jaringan polling terputus'), findsNothing);
    final count = api.polls;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(api.polls, count);
  });
  testWidgets(
    'failed request regenerates deliberately with new key and copy works',
    (tester) async {
      final api = FakeAi()
        ..enabled = true
        ..state = 'failed';
      await mount(tester, api);
      await tester.tap(find.text('Riwayat riset'));
      await tester.pumpAndSettle();
      expect(find.textContaining('provider_timeout'), findsOneWidget);
      await tester.tap(find.text('Salin'));
      await tester.pumpAndSettle();
      expect(find.text('Tersalin'), findsOneWidget);
      expect(clipboardText, 'Pertanyaan tersimpan');
      await tester.tap(find.text('Buat ulang jawaban'));
      await tester.pump();
      await tester.pump();
      expect(api.sends.single['content'], 'Pertanyaan tersimpan');
      await tester.tap(find.text('Batalkan'));
      await tester.pumpAndSettle();
      final key = api.sends.single['idempotency_key'];
      await tester.tap(find.text('Buat ulang jawaban'));
      await tester.pump();
      await tester.pump();
      expect(api.sends.last['idempotency_key'], isNot(key));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('disabled assistant reads history, older messages and sources', (
    tester,
  ) async {
    final api = FakeAi();
    await mount(tester, api);
    expect(find.textContaining('belum tersedia'), findsOneWidget);
    await tester.tap(find.text('Riwayat riset'));
    await tester.pumpAndSettle();
    expect(find.text('Pertanyaan tersimpan'), findsOneWidget);
    expect(find.text('Jawaban eksperimen'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('ai-send'))).onPressed,
      isNull,
    );
    await tester.tap(find.text('Pesan lebih lama'));
    await tester.pumpAndSettle();
    expect(find.text('Pesan lama'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sumber dan metrik tepercaya'),
      150,
      scrollable: find.descendant(
        of: find.byKey(const Key('ai-messages')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Sumber dan metrik tepercaya'));
    await tester.pumpAndSettle();
    expect(find.textContaining('50.0 detik'), findsOneWidget);
    expect(find.textContaining('Tidak tersedia'), findsWidgets);
  });

  testWidgets('active history resumes polling, disables send and cancels', (
    tester,
  ) async {
    final api = FakeAi()
      ..enabled = true
      ..state = 'processing';
    await mount(tester, api);
    await tester.tap(find.text('Riwayat riset'));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byKey(const Key('ai-input')), 'Lanjutan');
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('ai-send'))).onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(api.polls, greaterThan(0));
    await tester.tap(find.text('Chat baru'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('ai-input')), 'Pesan baru');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('ai-send'))).onPressed,
      isNull,
    );
    await tester.tap(find.text('Buka permintaan aktif'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    expect(find.text('Dibatalkan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'transport retry preserves payload/key/context and accepted message is unique',
    (tester) async {
      final api = FakeAi()
        ..enabled = true
        ..failSend = true;
      await mount(tester, api, context: 3);
      await tester.enterText(
        find.byKey(const Key('ai-input')),
        'Jelaskan hasil',
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('ai-send'))).onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('ai-send')));
      await tester.pumpAndSettle();
      expect(find.text('Jaringan terputus'), findsOneWidget);
      await tester.tap(find.text('Coba kirim lagi'));
      await tester.pump();
      await tester.pump();
      expect(api.sends.length, 2);
      expect(api.sends[0], api.sends[1]);
      expect(api.sends[0]['analysis_record_id'], 3);
      expect(find.text('Jelaskan hasil'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mobile keyboard and history drawer fit without overflow; disposal stops polling',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, FakeAi());
      await tester.tap(find.byTooltip('Riwayat percakapan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riwayat riset'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(find.byKey(const Key('ai-input'))).dy,
        lessThan(544),
      );
      expect(
        tester.getBottomLeft(find.byKey(const Key('ai-input'))).dy,
        greaterThan(430),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
