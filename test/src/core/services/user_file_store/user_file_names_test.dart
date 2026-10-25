import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

/// Security review item 5: a received file's name is the sender's, so it
/// must not lie when shown and must not land on top of anything when stored
/// (`THREAT_MODEL.md` R14, R15).
void main() {
  const rlo = '\u{202E}'; // RIGHT-TO-LEFT OVERRIDE
  const lri = '\u{2066}'; // LEFT-TO-RIGHT ISOLATE
  const pdi = '\u{2069}'; // POP DIRECTIONAL ISOLATE
  const zwsp = '\u{200B}'; // ZERO WIDTH SPACE
  const chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

  group('UserFileNames.cleanPickedFileName', () {
    test("drops a provider's 'null-' prefix", () {
      expect(
        UserFileNames.cleanPickedFileName('null-20260920-WA0000.jpg'),
        '20260920-WA0000.jpg',
      );
    });

    test('leaves an ordinary name alone', () {
      expect(UserFileNames.cleanPickedFileName('report.pdf'), 'report.pdf');
      expect(
        UserFileNames.cleanPickedFileName('nullable.txt'),
        'nullable.txt',
      );
    });
  });

  group('UserFileNames.forDisplay', () {
    test('drops every direction control, so the name reads in its real order',
        () {
      expect(
        UserFileNames.forDisplay('invoice${rlo}fdp.exe'),
        'invoicefdp.exe',
      );
      const all = '\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}'
          '\u{2066}\u{2067}\u{2068}\u{2069}\u{200E}\u{200F}\u{061C}';
      expect(UserFileNames.forDisplay('a${all}b.txt'), 'ab.txt');
    });

    test('drops control characters', () {
      expect(UserFileNames.forDisplay('a\nb\u{0007}c\u{0085}.txt'), 'abc.txt');
    });

    test('keeps real letters, right-to-left scripts and emoji', () {
      for (final name in [
        'ანგარიში.pdf',
        'تقرير.pdf',
        'דוח.pdf',
        'family 👨‍👩‍👧.jpg',
        'report (1).pdf',
      ]) {
        expect(UserFileNames.forDisplay(name), name);
      }
    });
  });

  group('UserFileNames.safeChatFolderName', () {
    String folder(String chatName, {String id = chatId}) =>
        UserFileNames.safeChatFolderName(chatName: chatName, chatId: id);

    test('is the chat name plus a short stable piece of the chat id', () {
      expect(folder('Bob'), 'Bob (6f1e9b2c)');
      expect(folder('Bob'), folder('Bob'));
    });

    test('two chats never share a folder, whatever their names', () {
      const otherId = '0a1b2c3d-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
      expect(
        folder('Bob').toLowerCase(),
        isNot(folder('bob', id: otherId).toLowerCase()),
      );
      expect(folder('a/b'), isNot(folder('a:b', id: otherId)));
    });

    test('path separators and Windows-forbidden characters are replaced', () {
      expect(folder('../../Documents'), '_.._Documents (6f1e9b2c)');
      expect(folder(r'a\b/c'), 'a_b_c (6f1e9b2c)');
      expect(folder('a<b>c:d"e|f?g*h'), 'a_b_c_d_e_f_g_h (6f1e9b2c)');
      for (final name in ['/', '..', r'C:\Windows', '/etc/passwd']) {
        final result = folder(name);
        expect(result, isNot(contains('/')), reason: name);
        expect(result, isNot(contains(r'\')), reason: name);
        expect(result, isNot(contains(':')), reason: name);
      }
    });

    test('. and .. and names of only dots or spaces become "Chat"', () {
      for (final name in ['.', '..', '...', '   ', ' . . ', '']) {
        expect(folder(name), 'Chat (6f1e9b2c)', reason: '"$name"');
      }
    });

    test('leading and trailing dots and spaces go', () {
      expect(folder('  .hidden'), 'hidden (6f1e9b2c)');
      expect(folder('Work. . '), 'Work (6f1e9b2c)');
    });

    test('control, direction and invisible characters go', () {
      expect(folder('Bo\u{0000}b\n'), 'Bob (6f1e9b2c)');
      expect(folder('Bo${rlo}b$zwsp'), 'Bob (6f1e9b2c)');
      expect(folder('${lri}Bob$pdi'), 'Bob (6f1e9b2c)');
    });

    test('Windows device names are never a folder name on their own', () {
      for (final name in [
        'CON',
        'con',
        'PRN',
        'AUX',
        'NUL',
        'COM1',
        'com9',
        'LPT1',
        'lpt9',
        'COM¹',
        r'CONIN$',
        'nul.txt',
        'Con ',
      ]) {
        final result =
            UserFileNames.safeChatFolderName(chatName: name, chatId: '');
        final stem = result.split('.').first.trim().toUpperCase();
        expect(
          RegExp(r'^(CON|PRN|AUX|NUL|COM[0-9¹²³]|LPT[0-9¹²³]|CONIN\$)$')
              .hasMatch(stem),
          isFalse,
          reason: '$name → $result',
        );
      }
      expect(folder('CON'), 'CON_ (6f1e9b2c)');
      expect(folder('nul.txt'), 'nul_.txt (6f1e9b2c)');
      expect(folder('Console'), 'Console (6f1e9b2c)');
    });

    test('a very long name is cut to 60 characters before the id', () {
      final result = folder('x' * 300);
      expect(result, '${'x' * 60} (6f1e9b2c)');
      final emoji = folder('😀' * 100);
      expect(emoji.runes.length, 60 + ' (6f1e9b2c)'.length);
    });

    test('real names in any script are kept', () {
      expect(folder('ნინო'), 'ნინო (6f1e9b2c)');
      expect(folder('Team 2026 — Q4'), 'Team 2026 — Q4 (6f1e9b2c)');
    });

    test('an odd chat id still gives a usable folder name', () {
      expect(
        UserFileNames.safeChatFolderName(chatName: 'Bob', chatId: '../x/'),
        'Bob (x)',
      );
      expect(
        UserFileNames.safeChatFolderName(chatName: 'Bob', chatId: ''),
        'Bob',
      );
    });
  });

  group('UserFileNames.uniqueOutputPath', () {
    late Directory folder;

    setUp(() => folder = Directory.systemTemp.createTempSync('unique_names_'));
    tearDown(() => folder.deleteSync(recursive: true));

    String at(String name) => path.join(folder.path, name);

    test('a free name is used as it is', () async {
      expect(await UserFileNames.uniqueOutputPath(at('a.pdf')), at('a.pdf'));
    });

    test('a taken name gets (1), then (2), …; the existing files stay',
        () async {
      File(at('report.pdf')).writeAsStringSync('mine');
      expect(
        await UserFileNames.uniqueOutputPath(at('report.pdf')),
        at('report (1).pdf'),
      );
      File(at('report (1).pdf')).writeAsStringSync('mine too');
      expect(
        await UserFileNames.uniqueOutputPath(at('report.pdf')),
        at('report (2).pdf'),
      );
      expect(File(at('report.pdf')).readAsStringSync(), 'mine');
    });

    test("a running job's .part reserves its name", () async {
      File(at('report.pdf.part')).writeAsStringSync('');
      expect(
        await UserFileNames.uniqueOutputPath(at('report.pdf')),
        at('report (1).pdf'),
      );
    });

    test('a folder or a link with the name counts as taken', () async {
      Directory(at('photos')).createSync();
      expect(
        await UserFileNames.uniqueOutputPath(at('photos')),
        at('photos (1)'),
      );
      if (!Platform.isWindows) {
        Link(at('dangling.txt')).createSync(at('nowhere'));
        expect(
          await UserFileNames.uniqueOutputPath(at('dangling.txt')),
          at('dangling (1).txt'),
        );
      }
    });

    test('a .fuzz keeps its inner extension', () async {
      File(at('report.pdf.fuzz')).writeAsStringSync('');
      expect(
        await UserFileNames.uniqueOutputPath(at('report.pdf.fuzz')),
        at('report (1).pdf.fuzz'),
      );
    });

    test('names without an extension or starting with a dot', () async {
      File(at('README')).writeAsStringSync('');
      File(at('.env')).writeAsStringSync('');
      expect(
        await UserFileNames.uniqueOutputPath(at('README')),
        at('README (1)'),
      );
      expect(await UserFileNames.uniqueOutputPath(at('.env')), at('.env (1)'));
    });

    test('the numbered name keeps the real extension', () async {
      File(at('setup.exe')).writeAsStringSync('');
      final unique = await UserFileNames.uniqueOutputPath(at('setup.exe'));
      expect(unique, at('setup (1).exe'));
    });

    test('a numbered long name still fits 255 bytes with its .part', () async {
      final longName = '${'x' * 250}.pdf'; // 254 bytes, the longest allowed
      File(at(longName)).writeAsStringSync('');
      final unique = await UserFileNames.uniqueOutputPath(at(longName));
      final name = path.basename(unique);
      expect(name, endsWith(' (1).pdf'));
      expect(utf8.encode('$name.part').length, lessThanOrEqualTo(255));
    });

    test('a long free name is checked without throwing', () async {
      final longName = '${'x' * 250}.pdf';
      expect(await UserFileNames.uniqueOutputPath(at(longName)), at(longName));
    });
  });
}
