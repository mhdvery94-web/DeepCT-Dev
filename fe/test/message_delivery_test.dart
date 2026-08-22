import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/chat_message.dart';

void main() {
  test('a message from the server counts as sent', () {
    final message = ChatMessage.fromJson(const {
      'id': 4,
      'body': 'hello',
      'from_admin': false,
    });

    expect(message.delivery, MessageDelivery.sent);
  });

  test('an optimistic message is pending and carries no server id', () {
    final message = ChatMessage.pending(body: 'hello', fromAdmin: false);

    expect(message.delivery, MessageDelivery.pending);
    expect(message.body, 'hello');
    // Nothing on the server corresponds to it yet.
    expect(message.id, 0);
  });

  test('a pending message can be marked failed without losing its text', () {
    // The whole point: a send that fails must not eat what someone wrote.
    final failed = ChatMessage.pending(body: 'important', fromAdmin: false)
        .copyWith(delivery: MessageDelivery.failed);

    expect(failed.delivery, MessageDelivery.failed);
    expect(failed.body, 'important');
  });
}
