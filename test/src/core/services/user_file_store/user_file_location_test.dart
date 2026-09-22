import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';

/// T-0366: a file bubble prints the file's name and a place the user can
/// find, never a path — least of all an app-private `/data/user/0/...` one.
void main() {
  group('UserFileLocation.of', () {
    test('Android public Downloads → "Downloads › Fuzzzy Seal › <chat>"', () {
      final location = UserFileLocation.of(
        '/storage/emulated/0/Download/Fuzzzy Seal/Fz bot/20260920-WA0000.jpg.fuzz',
        isIOS: false,
      );

      expect(location.fileName, '20260920-WA0000.jpg.fuzz');
      expect(location.folderLine, 'Downloads › Fuzzzy Seal › Fz bot');
    });

    test('desktop Documents → "Documents › <chat>"', () {
      final location = UserFileLocation.of(
        '/Users/me/Documents/Fz bot/report.pdf',
        isIOS: false,
      );

      expect(location.fileName, 'report.pdf');
      expect(location.folderLine, 'Documents › Fz bot');
    });

    test('iOS Documents → the Files app\'s "On My iPhone › Fuzzzy Seal"', () {
      const iosPath =
          '/var/mobile/Containers/Data/Application/ABC/Documents/Fz bot/a.pdf';
      final location = UserFileLocation.of(iosPath, isIOS: true);

      expect(location.folderLine, 'On My iPhone › Fuzzzy Seal › Fz bot');
    });

    test(
        'a row from before files were public names app storage, not the '
        'private path', () {
      const privatePath = '/data/user/0/com.fuzzzycore.seal'
          '/app_flutter/Fz bot/null-20260920-WA0000.jpg.fuzz';
      final location = UserFileLocation.of(privatePath, isIOS: false);

      expect(location.fileName, 'null-20260920-WA0000.jpg.fuzz');
      expect(location.folderLine, 'App storage › Fz bot');
      expect(location.folderLine, isNot(contains('/data/user')));
    });

    test('an unknown root shows only the parent folder', () {
      final location =
          UserFileLocation.of('/tmp/somewhere/x.fuzz', isIOS: false);

      expect(location.folderLine, 'somewhere');
    });
  });

  group('UserFileLocation.cleanPickedFileName', () {
    test("drops a provider's 'null-' prefix", () {
      expect(
        UserFileLocation.cleanPickedFileName('null-20260920-WA0000.jpg'),
        '20260920-WA0000.jpg',
      );
    });

    test('leaves an ordinary name alone', () {
      expect(UserFileLocation.cleanPickedFileName('report.pdf'), 'report.pdf');
      expect(
        UserFileLocation.cleanPickedFileName('nullable.txt'),
        'nullable.txt',
      );
    });
  });
}
