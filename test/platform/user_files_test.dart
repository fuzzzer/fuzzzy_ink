import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The files the app produces land where the user can find them (T-0366):
/// these assertions pin the platform files a Dart test cannot exercise.
void main() {
  group('Android', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('legacy storage permission stops at API 28 (MediaStore from 29)', () {
      expect(
        manifest,
        contains(
          RegExp(
            r'<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"\s+android:maxSdkVersion="28"',
          ),
        ),
      );
    });

    test('the app has its own FileProvider rooted at Downloads', () {
      expect(
        manifest,
        contains(r'android:authorities="${applicationId}.userfiles"'),
      );
      expect(manifest, contains('android:resource="@xml/user_file_paths"'));
      final paths = File('android/app/src/main/res/xml/user_file_paths.xml')
          .readAsStringSync();
      expect(
        paths,
        contains('<external-path name="downloads" path="Download/" />'),
      );
      expect(paths, contains('<cache-path'));
    });

    test('MainActivity registers the user files channel', () {
      final activity = File(
        'android/app/src/main/kotlin/com/fuzzzycore/seal/MainActivity.kt',
      ).readAsStringSync();
      expect(activity, contains('UserFiles.CHANNEL'));
      final channel = File(
        'android/app/src/main/kotlin/com/fuzzzycore/seal/UserFiles.kt',
      ).readAsStringSync();
      expect(
        channel,
        contains('"com.fuzzzycore.seal/user_files"'),
      );
      expect(channel, contains('MediaStore.Downloads.EXTERNAL_CONTENT_URI'));
    });
  });

  group('iOS', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    test('Documents is exposed to the Files app, in place', () {
      for (final key in [
        'UIFileSharingEnabled',
        'LSSupportsOpeningDocumentsInPlace',
      ]) {
        expect(
          plist,
          contains(RegExp('<key>$key</key>\\s*<true/>')),
          reason: key,
        );
      }
    });

    test('"Show" may open the Files app', () {
      expect(plist, contains('<string>shareddocuments</string>'));
    });
  });
}
