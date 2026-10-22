import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

/// Security review item 4: on a computer "Open" handed any received file to
/// the system's default handler, so a received program or script ran. The
/// test host is a computer (macOS or Linux), where the desktop list applies.
void main() {
  group('DeviceFileInteractor.openFile', () {
    late Directory folder;

    setUp(() => folder = Directory.systemTemp.createTempSync('open_file_'));
    tearDown(() => folder.deleteSync(recursive: true));

    test('refuses a program before anything is launched', () async {
      final program = File(path.join(folder.path, 'setup.exe'))
        ..writeAsStringSync('MZ');

      await expectLater(
        DeviceFileInteractor.openFile(program.path),
        throwsA(
          isA<RiskyFileOpenRefused>()
              .having((e) => e.filePath, 'filePath', program.path),
        ),
      );
    });

    test('refuses a disguised name by its real extension', () async {
      for (final name in [
        'invoice\u{202E}fdp.exe',
        'run.BAT',
        'photo.jpg.lnk',
        'script.sh. ',
        'launcher.desktop',
      ]) {
        await expectLater(
          DeviceFileInteractor.openFile(path.join(folder.path, name)),
          throwsA(isA<RiskyFileOpenRefused>()),
          reason: name,
        );
      }
    });

    test('the refusal names the file in its real order', () {
      const refused = RiskyFileOpenRefused('/x/invoice\u{202E}fdp.exe');
      expect(refused.toString(), contains('invoicefdp.exe'));
      expect(refused.toString().runes, isNot(contains(0x202E)));
    });

    test(
        'an ordinary file is not refused (a missing one still throws as '
        'before)', () async {
      await expectLater(
        DeviceFileInteractor.openFile(path.join(folder.path, 'report.pdf')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
