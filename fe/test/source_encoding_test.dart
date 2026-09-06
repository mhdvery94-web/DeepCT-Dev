import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Byte sequences that mean a UTF-8 file was read as Windows-1252 and saved
/// again.
///
/// `•` is three bytes in UTF-8 (E2 80 A2). A tool that reads those as
/// Windows-1252 sees three separate characters — `â`, `€`, `¢` — and writing
/// them back produces `â€¢`, which is what the admin dashboard was showing
/// under Recent Activity: "by Administrator â€¢ 4d ago".
///
/// It is not a rendering fault. The mangled characters are in the source, so
/// no amount of setting a charset anywhere fixes it, and every save through
/// the same tool makes it worse — `prediction.dart` had a dash that had been
/// through the mill three times.
const _mojibake = ['â€', 'Ã¢', 'Ãƒ', 'Â°', 'Â '];

/// Everything under here is ours to keep clean.
const _roots = ['lib', 'test'];

void main() {
  test('no source file carries mangled UTF-8', () {
    final offenders = <String>[];

    for (final root in _roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        // This file names the sequences on purpose.
        if (entity.path.endsWith('source_encoding_test.dart')) continue;

        final lines = entity.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          if (_mojibake.any(lines[i].contains)) {
            offenders.add('${entity.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'mangled UTF-8 in:\n${offenders.join('\n')}',
    );
  });
}
