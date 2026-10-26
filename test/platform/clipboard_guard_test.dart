import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The native clipboard rules for a sensitive copy (a safe password), which a
/// Dart test cannot exercise (security review 2026-10-26). These pin the
/// platform sources; the behaviour itself needs a device check.
void main() {
  test('Android clears a sensitive copy without focus, timed natively', () {
    final guard = File(
      'android/app/src/main/kotlin/com/fuzzzycore/ink/Guard.kt',
    ).readAsStringSync();
    expect(guard, contains('handler.postDelayed(expire, expiresInMs)'));
    expect(guard, contains('clipboard.clearPrimaryClip()'));
    expect(guard, contains('fun onDestroy()'));
    expect(
      File('android/app/src/main/kotlin/com/fuzzzycore/ink/MainActivity.kt')
          .readAsStringSync(),
      contains('guard?.onDestroy()'),
    );
  });

  test('Windows keeps a sensitive copy out of history and the cloud', () {
    final window = File('windows/runner/flutter_window.cpp').readAsStringSync();
    for (final format in [
      'L"ExcludeClipboardContentFromMonitorProcessing"',
      'L"CanIncludeInClipboardHistory", 0',
      'L"CanUploadToCloudClipboard", 0',
    ]) {
      expect(window, contains(format));
    }
    expect(window, contains('call.method_name() == "copy"'));
    expect(window, contains('call.method_name() == "clearIfOurs"'));
  });

  test('macOS clears a sensitive copy when the app quits', () {
    final window =
        File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
    expect(window, contains('NSApplication.willTerminateNotification'));
    expect(window, contains('clearSensitiveCopy()'));
  });
}
