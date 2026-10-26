import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app switcher never shows the content of any screen (DESIGN.md section
/// 4.2). These assertions pin the native code a Dart test cannot run; the
/// iOS cover's decision is also unit-tested in `ios/RunnerTests`.
void main() {
  // The code only: comments may describe what it does not do.
  String code(String path) => File(path)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp('//.*'), '');

  test('Android 13+: no recents thumbnail of any screen', () {
    final activity =
        code('android/app/src/main/kotlin/com/fuzzzycore/ink/MainActivity.kt');
    expect(
      activity,
      contains(
        'if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {\n'
        '            setRecentsScreenshotEnabled(false)',
      ),
    );
    expect(activity, contains('override fun onCreate('));
  });

  test('Android: private screens stay blank on every version', () {
    final guard =
        code('android/app/src/main/kotlin/com/fuzzzycore/ink/Guard.kt');
    expect(guard, contains('WindowManager.LayoutParams.FLAG_SECURE'));
  });

  test('iOS: inactive means the brand cover, whatever the screen', () {
    final delegate = code('ios/Runner/AppDelegate.swift');
    expect(delegate, contains('if isInactive { return .brand }'));
    expect(
      delegate,
      contains('name: UIApplication.willResignActiveNotification'),
    );
    expect(delegate, contains('case "setCover":'));
  });
}
