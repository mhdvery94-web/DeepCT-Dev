import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/chat_message.dart';
import 'package:fe/screens/messages/public_message_sheet.dart';
import 'package:fe/widgets/message_bubbles.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

ChatMessage _message({
  int id = 1,
  String body = 'hello',
  bool fromAdmin = false,
  String? author,
  DateTime? readAt,
  DateTime? createdAt,
}) => ChatMessage(
  id: id,
  body: body,
  fromAdmin: fromAdmin,
  author: author,
  readAt: readAt,
  createdAt: createdAt ?? DateTime(2026, 8, 15, 10, 30),
);

void main() {
  group('ChatMessage', () {
    test('reads the payload', () {
      final message = ChatMessage.fromJson(const {
        'id': 7,
        'body': 'The upload stops at 80%.',
        'from_admin': false,
        'author': 'Dyanna',
        'author_avatar_url': '/users/3/avatar',
        'read_at': '2026-08-15T04:00:00+00:00',
        'created_at': '2026-08-15T03:00:00+00:00',
      });

      expect(message.id, 7);
      expect(message.body, 'The upload stops at 80%.');
      expect(message.fromAdmin, isFalse);
      expect(message.author, 'Dyanna');
      expect(message.authorAvatarPath, '/users/3/avatar');
      expect(message.isRead, isTrue);
    });

    test('an unread message has no read stamp', () {
      final message = ChatMessage.fromJson(const {'id': 1, 'body': 'hi'});

      expect(message.isRead, isFalse);
      expect(message.readAt, isNull);
    });

    test('whose side a message is on depends on who is looking', () {
      // The same row renders on the right for the person who wrote it and on
      // the left for the person who received it.
      final fromResearcher = _message(fromAdmin: false);
      final fromAdmin = _message(fromAdmin: true);

      expect(fromResearcher.isMine(viewerIsAdmin: false), isTrue);
      expect(fromResearcher.isMine(viewerIsAdmin: true), isFalse);
      expect(fromAdmin.isMine(viewerIsAdmin: true), isTrue);
      expect(fromAdmin.isMine(viewerIsAdmin: false), isFalse);
    });
  });

  group('Conversation', () {
    test('reads a thread with its messages', () {
      final conversation = Conversation.fromJson(const {
        'id': 3,
        'name': 'Dyanna Basia',
        'is_guest': false,
        'is_archived': false,
        'unread': 2,
        'last_message_at': '2026-08-15T03:00:00+00:00',
        'user': {'email': 'dyanna@brin.go.id', 'avatar_url': '/users/3/avatar'},
        'messages': [
          {'id': 1, 'body': 'One', 'from_admin': false},
          {'id': 2, 'body': 'Two', 'from_admin': true},
        ],
      });

      expect(conversation.id, 3);
      expect(conversation.name, 'Dyanna Basia');
      expect(conversation.unread, 2);
      expect(conversation.userEmail, 'dyanna@brin.go.id');
      expect(conversation.userAvatarPath, '/users/3/avatar');
      expect(conversation.messages, hasLength(2));
      expect(conversation.isEmpty, isFalse);
    });

    test('a researcher who never wrote gets an empty thread, not an error', () {
      // The server returns a null id rather than 404: "no messages yet" is a
      // state the screen has to render anyway.
      final conversation = Conversation.fromJson(const {
        'id': null,
        'messages': [],
        'unread': 0,
        'is_guest': false,
      });

      expect(conversation.id, isNull);
      expect(conversation.isEmpty, isTrue);
    });

    test('a guest thread carries the address to reply to', () {
      final conversation = Conversation.fromJson(const {
        'id': 4,
        'name': 'Fajri',
        'is_guest': true,
        'guest_email': 'fajri@brin.go.id',
        'user': null,
      });

      expect(conversation.isGuest, isTrue);
      expect(conversation.guestEmail, 'fajri@brin.go.id');
      expect(conversation.userEmail, 'fajri@brin.go.id');
    });
  });

  group('MessageBubbleList', () {
    testWidgets('renders every message', (tester) async {
      await tester.pumpWidget(
        _host(
          MessageBubbleList(
            viewerIsAdmin: false,
            messages: [
              _message(id: 1, body: 'The upload stops at 80%.'),
              _message(id: 2, body: 'Which browser?', fromAdmin: true, author: 'Admin'),
            ],
          ),
        ),
      );

      expect(find.text('The upload stops at 80%.'), findsOneWidget);
      expect(find.text('Which browser?'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('shows the empty state when nothing has been said', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const MessageBubbleList(
            viewerIsAdmin: false,
            messages: [],
            emptyState: Text('No messages yet'),
          ),
        ),
      );

      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('a read message of my own gets the double tick', (tester) async {
      await tester.pumpWidget(
        _host(
          MessageBubbleList(
            viewerIsAdmin: false,
            messages: [_message(readAt: DateTime(2026, 8, 15, 11))],
          ),
        ),
      );

      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(find.byIcon(Icons.done), findsNothing);
    });

    testWidgets('an unread message of my own gets a single tick', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MessageBubbleList(viewerIsAdmin: false, messages: [_message()]),
        ),
      );

      expect(find.byIcon(Icons.done), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('the other side gets no tick at all', (tester) async {
      // Whether *I* have read *their* message is not a question anyone asks.
      await tester.pumpWidget(
        _host(
          MessageBubbleList(
            viewerIsAdmin: false,
            messages: [_message(fromAdmin: true, author: 'Admin')],
          ),
        ),
      );

      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('a run from one side shows its name once', (tester) async {
      await tester.pumpWidget(
        _host(
          MessageBubbleList(
            viewerIsAdmin: false,
            messages: [
              _message(id: 1, body: 'a', fromAdmin: true, author: 'Admin'),
              _message(id: 2, body: 'b', fromAdmin: true, author: 'Admin'),
              _message(id: 3, body: 'c', fromAdmin: true, author: 'Admin'),
            ],
          ),
        ),
      );

      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('lays out on a phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          MessageBubbleList(
            viewerIsAdmin: false,
            messages: [
              _message(
                id: 1,
                body: 'A long message that has to wrap inside its bubble '
                    'rather than push the row off the side of a narrow phone.',
                fromAdmin: true,
                author: 'Administrator',
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('MessageComposer', () {
    testWidgets('sends the trimmed text and clears the field', (tester) async {
      String? sent;

      await tester.pumpWidget(
        _host(MessageComposer(onSend: (body) async => sent = body)),
      );

      await tester.enterText(find.byType(TextField), '  hello  ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(sent, 'hello');
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
    });

    testWidgets('does not send an empty message', (tester) async {
      var calls = 0;

      await tester.pumpWidget(
        _host(MessageComposer(onSend: (_) async => calls++)),
      );

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('puts the text back when sending fails', (tester) async {
      // Losing what someone typed because the network dropped is the one
      // outcome a chat box must never have.
      await tester.pumpWidget(
        _host(
          MessageComposer(onSend: (_) async => throw Exception('offline')),
        ),
      );

      await tester.enterText(find.byType(TextField), 'important detail');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'important detail',
      );
    });
  });

  group('PublicMessageSheet', () {
    testWidgets('refuses to send until every field is filled in', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const PublicMessageSheet()));

      await tester.tap(find.text('SEND'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Describe the problem'), findsOneWidget);
    });

    testWidgets('rejects an address that is not one', (tester) async {
      await tester.pumpWidget(_host(const PublicMessageSheet()));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email we should reply to'),
        'not-an-address',
      );
      await tester.tap(find.text('SEND'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('lays out on a phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const PublicMessageSheet()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
