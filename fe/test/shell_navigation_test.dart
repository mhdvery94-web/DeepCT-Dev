import 'package:flutter_test/flutter_test.dart';

import 'package:fe/screens/admin/admin_shell.dart';
import 'package:fe/screens/user/user_shell.dart';

/// The section order a swipe walks through.
///
/// Pinned as a test because the swipe steps one place along this list, so
/// reordering the enum silently reorders navigation — and because the back
/// gesture goes home, and home is whatever sits first.
void main() {
  test('the researcher sections are in the order a swipe walks', () {
    expect(UserSection.values.first, UserSection.dashboard);

    // The "Model Training" tab was removed from the researcher console, so
    // 'training' is no longer one of them. A swipe walks this list and no
    // other.
    expect(
      UserSection.values.map((s) => s.name).toList(),
      ['dashboard', 'analysis', 'history', 'activity', 'messages'],
    );
  });

  test('stepping stops at both ends rather than wrapping', () {
    // Wrapping would put one swipe from the last entry onto the Dashboard,
    // which reads as losing your place rather than moving.
    expect(nextSection(UserSection.dashboard, -1), UserSection.dashboard);
    expect(nextSection(UserSection.messages, 1), UserSection.messages);
  });

  test('stepping moves exactly one place', () {
    expect(nextSection(UserSection.dashboard, 1), UserSection.analysis);
    expect(nextSection(UserSection.history, -1), UserSection.analysis);
  });

  test('the admin sections keep the Dashboard first', () {
    // The back gesture goes home, and home is whatever sits first.
    expect(AdminSection.values.first, AdminSection.dashboard);
  });

  test('admin stepping clamps and moves one place', () {
    expect(nextAdminSection(AdminSection.dashboard, -1), AdminSection.dashboard);
    expect(nextAdminSection(AdminSection.dashboard, 1), AdminSection.users);
    expect(
      nextAdminSection(AdminSection.values.last, 1),
      AdminSection.values.last,
    );
  });

  test('the researcher training tab is gone and stays gone', () {
    // The "Model Training" tab was removed from the researcher console.
    expect(
      UserSection.values.map((s) => s.name),
      isNot(contains('training')),
    );
  });

  test('the admin training tab is gone and stays gone', () {
    // Part D deleted it and moved what only it could do into Model
    // Management. A swipe walking back onto it would mean it came back.
    expect(
      AdminSection.values.map((s) => s.name),
      isNot(contains('training')),
    );
  });

  test('the admin queue tab is gone and stays gone', () {
    // The Queue tab was removed: it was read-only oversight that did not
    // drive the workflow, and live job visibility now lives in the
    // prediction history and the activity log.
    expect(
      AdminSection.values.map((s) => s.name),
      isNot(contains('queue')),
    );
  });
}
