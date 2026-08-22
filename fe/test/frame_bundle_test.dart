import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/utils/frame_bundle.dart';

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  test('several frames become one archive keeping their names', () async {
    // The numbering in the filename is what tells the backend where the gaps
    // are. Renaming would destroy exactly the information it needs.
    final bundle = await bundleFrames([
      (name: 'frame_001.tif', bytes: _bytes('one')),
      (name: 'frame_007.tif', bytes: _bytes('seven')),
    ]);

    final archive = ZipDecoder().decodeBytes(bundle.bytes);
    final names = archive.files.map((f) => f.name).toList()..sort();

    expect(names, ['frame_001.tif', 'frame_007.tif']);
    expect(bundle.filename, endsWith('.zip'));
  });

  test('the bytes of each frame survive the round trip', () async {
    final bundle = await bundleFrames([
      (name: 'frame_001.tif', bytes: _bytes('the actual pixels')),
    ]);

    final archive = ZipDecoder().decodeBytes(bundle.bytes);
    final content = String.fromCharCodes(
      archive.files.single.content as List<int>,
    );

    expect(content, 'the actual pixels');
  });

  test('a single frame is still bundled', () async {
    // The backend refuses one frame — interpolation needs two boundaries —
    // and it already has a message for that. Duplicating the rule here would
    // be two places that can disagree.
    final bundle = await bundleFrames([
      (name: 'frame_001.tif', bytes: _bytes('one')),
    ]);

    expect(ZipDecoder().decodeBytes(bundle.bytes).files, hasLength(1));
  });

  test('an empty list is a programming error, not a silent empty zip', () {
    expect(() => bundleFrames(const []), throwsArgumentError);
  });
}
