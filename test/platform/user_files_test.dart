import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app keeps only sealed files, in private storage, and hands a file to
/// the user only through the system save dialog or the share sheet: these
/// assertions pin the platform files a Dart test cannot exercise.
void main() {
  group('Android', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    // The code only: its comments may name what it no longer does.
    final channel = File(
      'android/app/src/main/kotlin/com/fuzzzycore/ink/UserFiles.kt',
    )
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp('//.*'), '');

    test('no storage permission at all', () {
      expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
      expect(manifest, isNot(contains('READ_EXTERNAL_STORAGE')));
      expect(manifest, isNot(contains('MANAGE_EXTERNAL_STORAGE')));
    });

    test('the FileProvider serves the private hand-off folder only', () {
      expect(
        manifest,
        contains(r'android:authorities="${applicationId}.userfiles"'),
      );
      expect(manifest, contains('android:resource="@xml/user_file_paths"'));
      final paths = File('android/app/src/main/res/xml/user_file_paths.xml')
          .readAsStringSync()
          .replaceAll(RegExp('<!--.*?-->', dotAll: true), '');
      final roots = RegExp('<[a-z-]+-path [^>]*/>').allMatches(paths).toList();
      expect(roots, hasLength(1));
      expect(
        roots.single.group(0),
        '<files-path name="handoff" path="handoff/" />',
      );
    });

    test('nothing goes to Downloads or the media index', () {
      for (final public in [
        'MediaStore',
        'DIRECTORY_DOWNLOADS',
        'MediaScannerConnection',
        'getExternalStoragePublicDirectory',
      ]) {
        expect(channel, isNot(contains(public)), reason: public);
      }
    });

    test('MainActivity registers the user files channel', () {
      final activity = File(
        'android/app/src/main/kotlin/com/fuzzzycore/ink/MainActivity.kt',
      ).readAsStringSync();
      expect(activity, contains('UserFiles.CHANNEL'));
      expect(channel, contains('"com.fuzzzycore.ink/user_files"'));
      expect(channel, contains('ActivityResultContracts.CreateDocument'));
    });
  });

  group('iOS', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    test("the app's folders are not shown in the Files app", () {
      for (final key in [
        'UIFileSharingEnabled',
        'LSSupportsOpeningDocumentsInPlace',
      ]) {
        expect(plist, isNot(contains(key)), reason: key);
      }
      expect(plist, isNot(contains('shareddocuments')));
    });
  });
}
