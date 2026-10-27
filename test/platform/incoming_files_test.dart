import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Fuzzzy Ink opens `.fuzz` files from other apps (`IncomingFiles`): these
/// assertions pin the platform registrations a Dart test cannot exercise.
void main() {
  String read(String path) => File(path).readAsStringSync();
  // The code only: comments may describe what it does not do.
  String code(String path) => read(path)
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp('//.*'), '');

  group('Android', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final filters = RegExp(
      '<intent-filter>(.*?)</intent-filter>',
      dotAll: true,
    )
        .allMatches(manifest)
        .map((match) => match.group(1)!)
        .where((filter) => filter.contains('android.intent.action.VIEW'))
        .toList();

    test('two VIEW filters for files, neither browsable nor verified', () {
      expect(filters, hasLength(2));
      for (final filter in filters) {
        expect(filter, contains('android.intent.category.DEFAULT'));
        expect(filter, isNot(contains('BROWSABLE')));
        expect(filter, contains('<data android:scheme="content" />'));
        expect(filter, isNot(contains('android:scheme="http')));
      }
    });

    test('a plain binary from any app, or a file named .fuzz', () {
      expect(
        filters.first,
        contains('<data android:mimeType="application/octet-stream" />'),
      );
      expect(
        filters.last,
        contains(r'<data android:pathPattern=".*\\.fuzz" />'),
      );
    });

    test('the native side only reads, and only into the hand-off folder', () {
      final userFiles =
          code('android/app/src/main/kotlin/com/fuzzzycore/ink/UserFiles.kt');
      expect(userFiles, contains('"copyIncoming" -> copyIncoming('));
      expect(userFiles, contains('contentResolver.openInputStream(uri)'));
      expect(userFiles, isNot(contains('openOutputStream(uri')));
      expect(
        userFiles,
        contains(
          'if (!target.canonicalPath.startsWith(handoff.path + File.separator))',
        ),
      );
    });
  });

  for (final platform in ['ios', 'macos']) {
    group(platform, () {
      final plist = read('$platform/Runner/Info.plist');

      test('opens the .fuzz type, which it declares', () {
        expect(plist, contains('<key>CFBundleDocumentTypes</key>'));
        expect(plist, contains('<key>UTExportedTypeDeclarations</key>'));
        expect(
          RegExp('<string>com.fuzzzycore.ink.fuzz</string>')
              .allMatches(plist)
              .length,
          2,
        );
        expect(
          plist,
          contains(
            '<key>public.filename-extension</key>\n'
            '\t\t\t\t<array>\n'
            '\t\t\t\t\t<string>fuzz</string>',
          ),
        );
        expect(plist, contains('<string>Viewer</string>'));
        expect(plist, isNot(contains('<string>Editor</string>')));
      });
    });
  }

  test('iOS hands over its own copy, never the file in place', () {
    final plist = read('ios/Runner/Info.plist');
    // Unset means no: a copy in Documents/Inbox (user_files_test.dart pins
    // that the app's folders stay out of the Files app).
    expect(plist, isNot(contains('<key>LSSupportsOpeningDocumentsInPlace')));
    expect(plist, isNot(contains('UIFileSharingEnabled')));
  });

  test('macOS: files from Finder reach Dart on the incoming channel', () {
    final delegate = code('macos/Runner/AppDelegate.swift');
    expect(delegate, contains('override func application('));
    expect(delegate, contains('InkIncoming.shared.add(files)'));
    expect(
      delegate,
      contains('static let channelName = "${IncomingFiles.channelName}"'),
    );
    expect(
      code('macos/Runner/MainFlutterWindow.swift'),
      contains('InkIncoming.shared.register('),
    );
  });
}
