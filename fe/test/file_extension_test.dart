import 'package:flutter_test/flutter_test.dart';

import 'package:fe/utils/file_extension.dart';

void main() {
  group('hasExtension', () {
    test('accepts the extension it was given', () {
      expect(hasExtension('frames.zip', const ['zip']), isTrue);
    });

    test('ignores case on both sides', () {
      // Android content providers and Windows both hand back names in
      // whichever case the file was created with.
      expect(hasExtension('FRAMES.ZIP', const ['zip']), isTrue);
      expect(hasExtension('photo.JPEG', const ['jpg', 'jpeg']), isTrue);
    });

    test('accepts any one of several extensions', () {
      const images = ['jpg', 'jpeg', 'png', 'webp'];
      expect(hasExtension('me.png', images), isTrue);
      expect(hasExtension('me.webp', images), isTrue);
      expect(hasExtension('me.gif', images), isFalse);
    });

    test('rejects a file with no extension at all', () {
      expect(hasExtension('frames', const ['zip']), isFalse);
    });

    test('reads only the last extension', () {
      // `.tar.gz` is not a zip, and `frames.zip.exe` is emphatically not one
      // either -- only the final segment counts.
      expect(hasExtension('frames.tar.gz', const ['zip']), isFalse);
      expect(hasExtension('frames.zip.exe', const ['zip']), isFalse);
    });

    test('handles a name that is nothing but a dot', () {
      expect(hasExtension('.', const ['zip']), isFalse);
    });

    test('handles an empty name', () {
      expect(hasExtension('', const ['zip']), isFalse);
    });
  });
}
