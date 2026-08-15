import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/support_ticket.dart';
import 'package:fe/screens/support/public_ticket_sheet.dart';

/// Wraps a widget in the minimum needed to pump it.
Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SupportTicket.fromJson', () {
    test('reads a ticket raised by a signed-in researcher', () {
      final ticket = SupportTicket.fromJson(const {
        'id': 7,
        'subject': 'Upload keeps failing',
        'category': 'upload',
        'status': 'in_progress',
        'priority': 'high',
        'awaiting_admin': false,
        'message_count': 3,
        'analysis_record_id': 12,
        'user': {'id': 2, 'name': 'Dyanna', 'email': 'dyanna@brin.go.id'},
        'is_guest': false,
        'created_at': '2026-08-15T02:00:00+00:00',
      });

      expect(ticket.id, 7);
      expect(ticket.statusLabel, 'IN PROGRESS');
      expect(ticket.isOpen, isTrue);
      expect(ticket.isClosed, isFalse);
      expect(ticket.userName, 'Dyanna');
      expect(ticket.isGuest, isFalse);
      expect(ticket.analysisRecordId, 12);
      expect(ticket.messages, isEmpty);
    });

    test('falls back to the guest name when there is no account', () {
      final ticket = SupportTicket.fromJson(const {
        'id': 8,
        'subject': 'Password no longer works',
        'status': 'open',
        'user': null,
        'guest': {'name': 'Fajri', 'email': 'fajri@brin.go.id'},
        'is_guest': true,
      });

      expect(ticket.isGuest, isTrue);
      expect(ticket.userName, 'Fajri');
      expect(ticket.userEmail, 'fajri@brin.go.id');
    });

    test('survives a payload with missing keys', () {
      final ticket = SupportTicket.fromJson(const {'id': 1});

      expect(ticket.subject, '');
      expect(ticket.category, 'other');
      expect(ticket.status, 'open');
      expect(ticket.priority, 'normal');
      expect(ticket.messageCount, 0);
      expect(ticket.userName, isNull);
    });

    test('reads the conversation when the detail endpoint includes it', () {
      final ticket = SupportTicket.fromJson(const {
        'id': 9,
        'subject': 'Download is empty',
        'status': 'open',
        'messages': [
          {'id': 1, 'body': 'The ZIP is 0 bytes.', 'from_admin': false},
          {
            'id': 2,
            'body': 'Which job id?',
            'from_admin': true,
            'author': 'Admin',
          },
        ],
      });

      expect(ticket.messages, hasLength(2));
      expect(ticket.messages.first.fromAdmin, isFalse);
      expect(ticket.messages.last.fromAdmin, isTrue);
      expect(ticket.messages.last.author, 'Admin');
    });
  });

  group('PublicTicketSheet', () {
    testWidgets('refuses to send until every field is filled in', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const PublicTicketSheet()));

      await tester.tap(find.text('SEND'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Subject is required'), findsOneWidget);
      expect(find.text('Describe the problem'), findsOneWidget);
    });

    testWidgets('rejects an address that is not one', (tester) async {
      await tester.pumpWidget(_host(const PublicTicketSheet()));

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

      await tester.pumpWidget(_host(const PublicTicketSheet()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
