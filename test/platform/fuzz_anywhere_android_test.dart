import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/native_strings/android_strings.dart' as native_strings;

/// "Lock from other apps" on Android (experimental, CHANNEL.md): what the
/// manifests may declare and what the native code may do. These pin the
/// platform files a Dart test cannot run; the sheet's logic has its own
/// Kotlin tests (android/app/src/test).
void main() {
  const app = 'android/app/src';
  const anywhere = '$app/main/kotlin/com/fuzzzycore/ink/anywhere';

  // The code only: comments may describe what it does not do.
  String code(String text) => text
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp('//.*'), '')
      .replaceAll(RegExp('<!--.*?-->', dotAll: true), '');

  String read(String path) => code(File(path).readAsStringSync());

  /// Every manifest that reaches a release build (debug and profile add
  /// INTERNET for the Flutter tool only, in debug and profile builds).
  final releaseManifests = [
    for (final source in Directory(app).listSync().whereType<Directory>())
      if (!{'debug', 'profile', 'test'}.contains(source.path.split('/').last) &&
          File('${source.path}/AndroidManifest.xml').existsSync())
        '${source.path}/AndroidManifest.xml',
  ];

  test('no network, overlay, accessibility or keyboard permission', () {
    expect(releaseManifests, contains('$app/main/AndroidManifest.xml'));
    expect(releaseManifests, contains('$app/development/AndroidManifest.xml'));
    for (final path in releaseManifests) {
      final manifest = read(path);
      for (final forbidden in [
        'android.permission.INTERNET',
        'android.permission.SYSTEM_ALERT_WINDOW',
        'android.permission.BIND_ACCESSIBILITY_SERVICE',
        'android.permission.BIND_INPUT_METHOD',
        'android.accessibilityservice',
        'android.view.InputMethod',
      ]) {
        expect(
          manifest,
          isNot(contains(forbidden)),
          reason: '$path: $forbidden',
        );
      }
    }
  });

  test('the selection menu item is declared in development only, and off', () {
    for (final path in releaseManifests) {
      if (path.contains('/development/')) continue;
      final manifest = read(path);
      expect(manifest, isNot(contains('PROCESS_TEXT')), reason: path);
      expect(manifest, isNot(contains('.anywhere.')), reason: path);
    }
    final development = read('$app/development/AndroidManifest.xml');
    final activity = RegExp(
      r'<activity\s[^>]*android:name="com\.fuzzzycore\.ink\.anywhere\.InkTextActivity"[^>]*>(.*?)</activity>',
      dotAll: true,
    ).firstMatch(development);
    expect(activity, isNotNull);
    final declaration = activity!.group(0)!;
    expect(declaration, contains('android:enabled="false"'));
    expect(declaration, contains('android:exported="true"'));
    expect(declaration, contains('android.intent.action.PROCESS_TEXT'));
    expect(declaration, contains('android:mimeType="text/plain"'));
    expect(development, contains('android.permission.HIDE_OVERLAY_WINDOWS'));
  });

  test('every declared entry point is declared off and is one the switch knows',
      () {
    final development = read('$app/development/AndroidManifest.xml');
    final switcher = read('$anywhere/AnywhereSwitch.kt');
    final declared = RegExp(
      r'<(activity|service)\s[^>]*?android:name="(com\.fuzzzycore\.ink\.anywhere\.\w+)"[^>]*>',
      dotAll: true,
    ).allMatches(development).toList();
    expect(declared, isNotEmpty);
    for (final entry in declared) {
      expect(
        entry.group(0),
        contains('android:enabled="false"'),
        reason: entry.group(2),
      );
      expect(switcher, contains('"${entry.group(2)}"'), reason: entry.group(2));
    }
  });

  test('the native code does no cryptography, no networking and no logging',
      () {
    final sources = Directory(anywhere)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.kt'));
    expect(sources, isNotEmpty);
    for (final file in sources) {
      final source = read(file.path);
      for (final forbidden in [
        'javax.crypto',
        'java.security',
        'com.google.crypto',
        'java.net',
        'okhttp',
        'Socket',
        'android.util.Log',
        'println',
        'ClipboardManager',
        'SelectionContainer',
        'putString(',
      ]) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason: '${file.path}: $forbidden',
        );
      }
      expect(source, isNot(contains(RegExp(r'\bLog\.'))), reason: file.path);
    }
  });

  test('only sealed lock output goes back to the other app', () {
    final activity = read('$anywhere/InkTextActivity.kt');
    expect(
      RegExp('EXTRA_PROCESS_TEXT[^_]').allMatches(activity).length,
      2,
      reason: 'read once from the intent, set once in finishWith',
    );
    expect(
      activity,
      contains(
        'setResult(RESULT_OK, Intent().putExtra(Intent.EXTRA_PROCESS_TEXT, returnText))',
      ),
    );
    final model = read('$anywhere/SheetViewModel.kt');
    // The only text that ever becomes a return text is `lock`'s output.
    expect(
      RegExp(r'finish\((\w+)\)')
          .allMatches(model)
          .map((m) => m.group(1))
          .toSet(),
      {'output'},
    );
    expect(model, contains('val output = answer.string("output")'));
    expect(model, contains('finish(done?.returnText)'));
  });

  test('the sheet is out of screenshots and hides overlays', () {
    final activity = read('$anywhere/InkTextActivity.kt');
    expect(
      activity,
      contains('window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)'),
    );
    expect(activity, contains('window.setHideOverlayWindows(true)'));
    expect(activity, contains('channel.send("relock")'));
    final sheet = read('$anywhere/ui/InkSheet.kt');
    expect(sheet, contains('securePolicy = SecureFlagPolicy.SecureOn'));
  });

  test('the native strings are generated from the .arb files, both languages',
      () {
    final expected = native_strings.expectedFiles();
    expect(expected.keys, hasLength(2));
    for (final MapEntry(key: path, value: content) in expected.entries) {
      expect(
        File(path).readAsStringSync(),
        content,
        reason: '$path is stale: run tools/native_strings/android_strings.dart',
      );
    }
  });
}
