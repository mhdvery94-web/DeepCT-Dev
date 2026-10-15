import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/screens/assistant/research_assistant_screen.dart';
import 'package:fe/services/ai_service.dart';
import 'package:fe/services/ai_chat_controller.dart';
import 'package:fe/services/api_client.dart';

class FakeAi extends AiService {
  bool enabled = false;
  String? mode;
  bool failAnalyses = false, emptyAnalyses = false;
  Completer<Map<String, dynamic>>? delayedAnalyses;
  final List<int> analysisPages = [];

  @override
  Future<Map<String, dynamic>> analyses({int page = 1}) async {
    analysisPages.add(page);
    if (delayedAnalyses != null) return delayedAnalyses!.future;
    if (failAnalyses) throw const ApiException('Daftar analisis terputus');
    return {
      'data': emptyAnalyses
          ? []
          : [
              {
                'id': 3,
                'status': 'completed',
                'expired': true,
                'files_deleted': true,
              },
              if (page == 2) {'id': 24, 'status': 'failed'},
            ],
      'pagination': {
        'current_page': page,
        'last_page': emptyAnalyses ? 1 : 2,
        'per_page': 20,
        'total': emptyAnalyses ? 0 : 21,
      },
    };
  }

  String state = 'completed';
  bool failSend = false;
  bool failPoll = false;
  ApiException? rejection;
  final List<Map<String, dynamic>> sends = [];
  int polls = 0;
  int? originalContextId;
  Map<String, dynamic> get request => {
    'id': 42,
    'conversation_id': 7,
    'user_message_id': 100,
    'analysis_record_id': originalContextId,
    'status': state,
    'error_code': state == 'failed' ? 'provider_timeout' : null,
    'assistant_message': state == 'completed'
        ? {'id': 101, 'role': 'assistant', 'content': 'Jawaban eksperimen'}
        : null,
    'sources': state == 'completed'
        ? [
            {
              'type': 'analysis_record',
              'id': 3,
              'status': 'pending',
              'processing_time_seconds': null,
              'metrics': {'mae': null},
            },
          ]
        : [],
    'metrics': {'total_duration': 50000000000},
  };
  @override
  Future<Map<String, dynamic>> get(String path, {int page = 1}) async {
    if (path == 'status') {
      return {
        'enabled': enabled,
        if (mode != null) 'mode': mode,
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
    originalContextId = data['analysis_record_id'] as int?;
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
  testWidgets(
    'metadata picker admits second-page owned context, then clears it',
    (tester) async {
      final api = FakeAi()
        ..enabled = true
        ..mode = 'metadata';
      await mount(tester, api, context: 99);
      expect(api.analysisPages, [1]);
      expect(find.textContaining('#99'), findsWidgets);
      await tester.tap(find.text('Muat analisis lainnya'));
      await tester.pumpAndSettle();
      expect(api.analysisPages, [1, 2]);
      await tester.tap(find.byKey(const Key('ai-context-picker')));
      await tester.pumpAndSettle();
      expect(
        find.text('Analisis #3 · completed').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Analisis #24 · failed').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('ai-input')),
        'Jelaskan analisis',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai-send')));
      await tester.pump();
      await tester.pump();
      expect(api.sends.single['analysis_record_id'], 24);
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byKey(const Key('ai-context-picker')),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Lepas konteks'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Batalkan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lepas konteks'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('ai-input')),
        'Tanpa konteks',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai-send')));
      await tester.pump();
      await tester.pump();
      expect(api.sends.last.containsKey('analysis_record_id'), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'metadata listing retry and empty state retain deep-link context',
    (tester) async {
      final api = FakeAi()
        ..enabled = true
        ..mode = 'metadata'
        ..failAnalyses = true;
      await mount(tester, api, context: 99);
      expect(find.text('Daftar analisis terputus'), findsOneWidget);
      expect(find.textContaining('#99'), findsWidgets);
      api.failAnalyses = false;
      api.emptyAnalyses = true;
      await tester.tap(find.text('Coba muat analisis lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada analisis milik Anda.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ai-input')), 'Konteks awal');
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai-send')));
      await tester.pump();
      await tester.pump();
      expect(api.sends.single['analysis_record_id'], 99);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('late metadata list never updates disposed screen', (
    tester,
  ) async {
    final api = FakeAi()
      ..enabled = true
      ..mode = 'metadata'
      ..delayedAnalyses = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: ResearchAssistantScreen(service: api, analysisRecordId: 99),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Memuat analisis…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.delayedAnalyses!.complete({
      'data': [],
      'pagination': {'current_page': 1, 'last_page': 1},
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  test(
    'selection guard preserves retry admission and unresolved global request context',
    () async {
      final api = FakeAi()
        ..enabled = true
        ..mode = 'metadata'
        ..failSend = true;
      final chat = AiChatController(api, contextId: 99);
      addTearDown(chat.dispose);
      await chat.initialize();
      expect(await chat.send('Pertanyaan asli'), isFalse);
      chat.selectContext(3);
      chat.clearContext();
      expect(chat.contextId, 99);
      expect(await chat.send('Teks berbeda', retry: true), isTrue);
      expect(api.sends[0], api.sends[1]);
      chat.newChat();
      chat.selectContext(24);
      expect(chat.contextId, 99);
      api.state = 'failed';
      await chat.open({'id': 7});
      chat.selectContext(24);
      expect(chat.contextId, 24);
      expect(await chat.regenerate(), isTrue);
      expect(api.sends.last['analysis_record_id'], 99);
    },
  );
  testWidgets(
    'later page errors preserve explicit selection and retry same page',
    (tester) async {
      final api = FakeAi()
        ..enabled = true
        ..mode = 'metadata';
      await mount(tester, api, context: 99);
      await tester.tap(find.byKey(const Key('ai-context-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analisis #3 · completed').last);
      await tester.pumpAndSettle();
      api.failAnalyses = true;
      await tester.tap(find.text('Muat analisis lainnya'));
      await tester.pumpAndSettle();
      expect(find.text('Daftar analisis terputus'), findsOneWidget);
      expect(find.text('Konteks prediksi #3'), findsOneWidget);
      api.failAnalyses = false;
      await tester.tap(find.text('Coba muat analisis lagi'));
      await tester.pumpAndSettle();
      expect(api.analysisPages, [1, 2, 2]);
      expect(find.text('Konteks prediksi #3'), findsOneWidget);
      await tester.tap(find.text('Riwayat riset'));
      await tester.pumpAndSettle();
      expect(find.text('Konteks prediksi #3'), findsOneWidget);
      await tester.tap(find.text('Chat baru'));
      await tester.pumpAndSettle();
      expect(find.text('Konteks prediksi #3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('metadata picker fits mobile keyboard without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(
      tester,
      FakeAi()
        ..enabled = true
        ..mode = 'metadata',
      context: 99,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomLeft(find.byKey(const Key('ai-input'))).dy,
      lessThan(544),
    );
    await tester.tap(find.byKey(const Key('ai-context-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Analisis #3 · completed').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('legacy mode does not fetch owned analyses', (tester) async {
    final api = FakeAi()..enabled = true;
    await mount(tester, api);
    expect(api.analysisPages, isEmpty);
    expect(find.byKey(const Key('ai-context-picker')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  for (final state in ['failed', 'cancelled']) {
    for (final composerContext in [null, 9]) {
      testWidgets(
        '$state history regeneration retains original prediction via entry $composerContext',
        (tester) async {
          final api = FakeAi()
            ..enabled = true
            ..state = state
            ..originalContextId = 3;
          await mount(tester, api, context: composerContext);
          await tester.tap(find.text('Riwayat riset'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Buat ulang jawaban'));
          await tester.pump();
          await tester.pump();
          expect(api.sends.single['analysis_record_id'], 3);
          expect(api.sends.single['content'], 'Pertanyaan tersimpan');
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final state in ['failed', 'cancelled']) {
    testWidgets(
      '$state context-free original stays context-free despite selected composer prediction',
      (tester) async {
        final api = FakeAi()
          ..enabled = true
          ..state = state;
        await mount(tester, api, context: 9);
        await tester.tap(find.text('Riwayat riset'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buat ulang jawaban'));
        await tester.pump();
        await tester.pump();
        expect(api.sends.single.containsKey('analysis_record_id'), isFalse);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'polled request context survives composer context removal before regeneration',
    (tester) async {
      final api = FakeAi()
        ..enabled = true
        ..state = 'processing'
        ..originalContextId = 3;
      await mount(tester, api, context: 9);
      await tester.tap(find.text('Riwayat riset'));
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Lepas konteks'),
            )
            .onPressed,
        isNull,
      );
      api.state = 'failed';
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.tap(find.text('Lepas konteks'));
      await tester.pump();
      await tester.tap(find.text('Buat ulang jawaban'));
      await tester.pump();
      await tester.pump();
      expect(api.sends.single['analysis_record_id'], 3);
      await tester.pumpWidget(const SizedBox());
    },
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
