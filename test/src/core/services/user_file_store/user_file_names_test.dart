import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

/// Security review items 4 and 5: a received file's name is the sender's, so
/// it must not run when opened, must not lie when shown, and must not land
/// on top of anything when stored (`THREAT_MODEL.md` R14, R15).
void main() {
  const rlo = '\u{202E}'; // RIGHT-TO-LEFT OVERRIDE
  const lri = '\u{2066}'; // LEFT-TO-RIGHT ISOLATE
  const pdi = '\u{2069}'; // POP DIRECTIONAL ISOLATE
  const rlm = '\u{200F}'; // RIGHT-TO-LEFT MARK
  const alm = '\u{061C}'; // ARABIC LETTER MARK
  const zwsp = '\u{200B}'; // ZERO WIDTH SPACE
  const bom = '\u{FEFF}';
  const chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

  const desktops = [
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ];

  group('UserFileNames.isRiskyToOpen', () {
    test('Windows programs, scripts and shortcuts are risky on every desktop',
        () {
      const names = [
        'setup.exe',
        'run.bat',
        'run.cmd',
        'old.com',
        'saver.scr',
        'x.pif',
        'link.lnk',
        'site.url',
        'a.js',
        'a.jse',
        'a.vbs',
        'a.vbe',
        'a.wsf',
        'a.wsh',
        'a.hta',
        'a.ps1',
        'a.msi',
        'a.msp',
        'a.reg',
        'a.cpl',
        'a.jar',
        'a.appref-ms',
        'a.application',
        'a.library-ms',
        'a.settingcontent-ms',
        'a.msix',
        'a.appinstaller',
        'a.iso',
        'a.vhdx',
        'a.chm',
        'a.scf',
        'a.rdp',
        'a.inf',
        'a.xll',
        'a.website',
        'a.search-ms',
        'a.searchconnector-ms',
        'a.psm1',
        'a.cer',
      ];
      for (final platform in desktops) {
        for (final name in names) {
          expect(
            UserFileNames.isRiskyToOpen(name, platform: platform),
            isTrue,
            reason: '$name on $platform',
          );
        }
      }
    });

    test('macOS and Linux launchers and installers are risky', () {
      const names = [
        'x.app',
        'x.command',
        'x.tool',
        'x.terminal',
        'x.sh',
        'x.zsh',
        'x.pkg',
        'x.mpkg',
        'x.dmg',
        'x.webloc',
        'x.fileloc',
        'x.scpt',
        'x.desktop',
        'x.run',
        'x.AppImage',
        'x.deb',
        'x.rpm',
        'x.py',
        'x.flatpakref',
      ];
      for (final platform in desktops) {
        for (final name in names) {
          expect(
            UserFileNames.isRiskyToOpen(name, platform: platform),
            isTrue,
            reason: '$name on $platform',
          );
        }
      }
    });

    test('Office files with macros, add-ins and fetched content are risky', () {
      const names = [
        'a.docm',
        'a.dotm',
        'a.xlsm',
        'a.xltm',
        'a.xlam',
        'a.xla',
        'a.xlm',
        'a.pptm',
        'a.potm',
        'a.ppam',
        'a.ppsm',
        'a.sldm',
        'a.wll',
        'a.vsto',
        'a.iqy',
        'a.slk',
        'a.one',
        'a.onepkg',
        'a.mht',
        'a.mhtml',
        'a.settingcontent-ms',
        'Budget.XLSM',
      ];
      for (final platform in desktops) {
        for (final name in names) {
          expect(
            UserFileNames.isRiskyToOpen(name, platform: platform),
            isTrue,
            reason: '$name on $platform',
          );
        }
      }
      // Phones open none of these with something that runs it.
      expect(
        UserFileNames.isRiskyToOpen('a.docm', platform: TargetPlatform.android),
        isFalse,
      );
    });

    test('ordinary documents, media and archives open', () {
      const names = [
        'report.pdf',
        'photo.jpg',
        'notes.txt',
        'book.docx',
        'sheet.xlsx',
        'slides.pptx',
        'song.mp3',
        'clip.mp4',
        'bundle.zip',
        'page.html',
        'README',
        'report.pdf.fuzz',
        '.bashrc',
        'exe',
        'invoice.exe.pdf',
      ];
      for (final platform in [...desktops, TargetPlatform.android]) {
        for (final name in names) {
          expect(
            UserFileNames.isRiskyToOpen(name, platform: platform),
            isFalse,
            reason: '$name on $platform',
          );
        }
      }
    });

    test('case is ignored', () {
      for (final name in ['SETUP.EXE', 'Run.Bat', 'x.Lnk', 'x.APK']) {
        final platform = name.endsWith('APK')
            ? TargetPlatform.android
            : TargetPlatform.windows;
        expect(
          UserFileNames.isRiskyToOpen(name, platform: platform),
          isTrue,
          reason: name,
        );
      }
    });

    test('a direction override cannot hide the real extension', () {
      // Shown as "invoiceexe.pdf", really ends in ".exe".
      const disguised = 'invoice${rlo}fdp.exe';
      expect(
        UserFileNames.isRiskyToOpen(
          disguised,
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
      expect(
        UserFileNames.isRiskyToOpen(
          'photo$lri.jpg$pdi.scr',
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
    });

    test('invisible characters inside the extension do not hide it', () {
      for (final name in [
        'a.e${zwsp}xe',
        'a.ex${bom}e',
        'a.$rlm${alm}exe',
        'a.b\u{00AD}at',
      ]) {
        expect(
          UserFileNames.isRiskyToOpen(name, platform: TargetPlatform.windows),
          isTrue,
          reason: name.runes.toList().toString(),
        );
      }
    });

    test('trailing dots and spaces (dropped by Windows) do not hide it', () {
      for (final name in ['a.exe.', 'a.exe ', 'a.exe. . .', 'a.bat\u{00A0}']) {
        expect(
          UserFileNames.isRiskyToOpen(name, platform: TargetPlatform.windows),
          isTrue,
          reason: name,
        );
      }
    });

    test('an NTFS stream name does not hide it', () {
      expect(
        UserFileNames.isRiskyToOpen(
          r'a.exe::$DATA',
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
      expect(
        UserFileNames.isRiskyToOpen(
          'a.exe:Zone.Identifier',
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
    });

    test('a {CLSID} extension is risky', () {
      expect(
        UserFileNames.isRiskyToOpen(
          'report.pdf.{3050F4D8-98B5-11CF-BB82-00AA00BDCE0B}',
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
    });

    test('Android refuses app packages only', () {
      for (final name in ['app.apk', 'app.apks', 'app.xapk', 'app.apkm']) {
        expect(
          UserFileNames.isRiskyToOpen(name, platform: TargetPlatform.android),
          isTrue,
          reason: name,
        );
      }
      expect(
        UserFileNames.isRiskyToOpen(
          'setup.exe',
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
      expect(
        UserFileNames.isRiskyToOpen(
          'evil${rlo}kpa.apk',
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
    });

    test('iOS runs nothing it opens', () {
      for (final name in ['setup.exe', 'app.apk', 'x.sh']) {
        expect(
          UserFileNames.isRiskyToOpen(name, platform: TargetPlatform.iOS),
          isFalse,
        );
      }
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

  group('UserFileNames.chatFolderPath', () {
    const documents = '/home/me/Documents';

    test('a computer writes under Documents/Fuzzzy Ink/<safe chat folder>', () {
      for (final platform in desktops) {
        expect(
          UserFileNames.chatFolderPath(
            documentsPath: documents,
            chatName: 'Work',
            chatId: chatId,
            platform: platform,
          ),
          path.join(documents, 'Fuzzzy Ink', 'Work (6f1e9b2c)'),
          reason: '$platform',
        );
      }
    });

    test('a hostile chat name stays inside Documents/Fuzzzy Ink', () {
      final folder = UserFileNames.chatFolderPath(
        documentsPath: documents,
        chatName: '../../../etc',
        chatId: chatId,
        platform: TargetPlatform.linux,
      );
      expect(
        path.isWithin(path.join(documents, 'Fuzzzy Ink'), folder),
        isTrue,
      );
      expect(path.dirname(folder), path.join(documents, 'Fuzzzy Ink'));
    });

    test('a hostile chat name stays inside the phone documents folder', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final name in ['.', '..', 'a/b', '../../../etc', '/abs']) {
          final folder = UserFileNames.chatFolderPath(
            documentsPath: documents,
            chatName: name,
            chatId: chatId,
            platform: platform,
          );
          expect(
            path.dirname(folder),
            documents,
            reason: '$name on $platform',
          );
          expect(path.isWithin(documents, folder), isTrue);
        }
      }
    });

    test('phones keep their folder: <documents>/<chat name>', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(
          UserFileNames.chatFolderPath(
            documentsPath: documents,
            chatName: 'Work',
            chatId: chatId,
            platform: platform,
          ),
          path.join(documents, 'Work'),
          reason: '$platform',
        );
      }
    });
  });

  group('UserFileNames.phoneChatFolderName', () {
    test('ordinary names keep the folder they always had', () {
      for (final name in [
        'Work',
        'Mom & Dad?',
        'Q: plans "2026"',
        'მეგობრები',
        'Ünïcödé 🎉',
        'CON',
        'a.b',
        'x' * 80,
        'Family 👨\u200D👩\u200D👧',
      ]) {
        expect(UserFileNames.phoneChatFolderName(name), name, reason: name);
      }
    });

    test('. and .. and names of only dots or spaces become "Chat"', () {
      for (final name in ['.', '..', '...', ' . ', '']) {
        expect(UserFileNames.phoneChatFolderName(name), 'Chat', reason: name);
      }
    });

    test('path separators cannot make a second folder level', () {
      expect(UserFileNames.phoneChatFolderName('a/b'), 'a_b');
      expect(UserFileNames.phoneChatFolderName(r'a\b'), 'a_b');
      expect(UserFileNames.phoneChatFolderName('../../etc'), '_.._etc');
      expect(UserFileNames.phoneChatFolderName('/abs'), '_abs');
    });

    test('control and direction characters go', () {
      expect(
        UserFileNames.phoneChatFolderName('Bo${rlo}b\u0000$lri$pdi\n'),
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

    test('the numbered name keeps the real extension of a risky file',
        () async {
      File(at('setup.exe')).writeAsStringSync('');
      final unique = await UserFileNames.uniqueOutputPath(at('setup.exe'));
      expect(unique, at('setup (1).exe'));
      expect(
        UserFileNames.isRiskyToOpen(
          path.basename(unique),
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
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
