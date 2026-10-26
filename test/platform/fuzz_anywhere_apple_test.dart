import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/native_strings/apple_strings.dart' as native_strings;

/// "Lock from other apps" on the Mac and the iPhone (experimental,
/// `documents/fuzz_anywhere/CHANNEL.md`): what the native pieces may
/// declare and use. The Services menu exists only in the development
/// flavour, asks for no permission and needs no sandbox exception; the
/// native code does no cryptography, no networking and no logging, and
/// shows only strings generated from the app's own `.arb` files.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final macProject = read('macos/Runner.xcodeproj/project.pbxproj');
  final iosProject = read('ios/Runner.xcodeproj/project.pbxproj');
  final services = read('macos/Runner/Anywhere/Services-development.plist');
  final servicesScript = read('macos/Runner/Anywhere/add_services_menu.sh');

  List<File> swiftIn(String folder) => Directory(folder)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.swift'))
      .toList();

  final nativeSwift = [
    ...swiftIn('apple/Anywhere'),
    ...swiftIn('macos/Runner/Anywhere'),
    ...swiftIn('ios/Runner/Anywhere'),
  ];

  /// Each entry of the NSServices array, as text (from its menu title to
  /// the next entry's).
  List<String> serviceEntries() =>
      services.split('<key>NSMenuItem</key>').skip(1).toList();

  group('the Mac Services menu', () {
    test('is not in the Info.plist every flavour shares', () {
      expect(
        read('macos/Runner/Info.plist'),
        isNot(contains('<key>NSServices</key>')),
      );
    });

    test('is added for the development configurations only', () {
      expect(servicesScript, contains('*-development) ;;'));
      expect(servicesScript, contains('*) exit 0 ;;'));
      expect(servicesScript, contains('Services-development.plist'));
      expect(
        macProject,
        contains(
          r'shellScript = "\"${SRCROOT}/Runner/Anywhere/add_services_menu.sh\"\n";',
        ),
      );
    });

    test('has Lock (in place) and Open, each with a required context', () {
      final entries = serviceEntries();
      expect(entries, hasLength(2));
      for (final entry in entries) {
        expect(
          entry,
          matches(RegExp(r'<key>NSRequiredContext</key>\s*<dict/>')),
        );
        expect(entry, contains('public.utf8-plain-text'));
      }
      final lock = entries.firstWhere((e) => e.contains('lockText'));
      expect(lock, contains('<key>NSReturnTypes</key>'));
      expect(lock, contains('<string>120000</string>'));
      final open = entries.firstWhere((e) => e.contains('openText'));
      expect(
        open,
        isNot(contains('NSReturnTypes')),
        reason: 'Open never writes anything back into the other app',
      );
    });

    test('needs no sandbox exception', () {
      expect(services, isNot(contains('<key>NSRestricted</key>')));
    });
  });

  group('no permission is asked for', () {
    const usageKeys = [
      'NSAccessibilityUsageDescription',
      'NSScreenCaptureUsageDescription',
      'NSAppleEventsUsageDescription',
      'NSInputMonitoringUsageDescription',
      'NSPasteboardUsageDescription',
    ];

    test('no usage string for Accessibility, screen capture, automation', () {
      for (final path in [
        'macos/Runner/Info.plist',
        'ios/Runner/Info.plist',
        'macos/Runner/Anywhere/Services-development.plist',
      ]) {
        final plist = read(path);
        for (final key in usageKeys) {
          expect(plist, isNot(contains(key)), reason: '$path: $key');
        }
      }
    });

    test('no network or automation entitlement was added', () {
      for (final path in [
        'macos/Runner/DebugProfile.entitlements',
        'macos/Runner/Release.entitlements',
        'ios/Runner/Runner.entitlements',
      ]) {
        final entitlements = read(path);
        expect(entitlements, isNot(contains('network.client')), reason: path);
        expect(entitlements, isNot(contains('automation')), reason: path);
        expect(
          entitlements,
          isNot(contains('temporary-exception')),
          reason: path,
        );
      }
    });
  });

  group('the iPhone App Shortcut', () {
    test('is compiled into the development configurations only', () {
      final configs = RegExp(
        'isa = XCBuildConfiguration;(.*?)name = "?([^";]+)"?;',
        dotAll: true,
      ).allMatches(iosProject);
      final withShortcut = [
        for (final config in configs)
          if (config.group(1)!.contains('INK_ANYWHERE')) config.group(2),
      ];
      expect(
        withShortcut,
        unorderedEquals([
          'Debug-development',
          'Profile-development',
          'Release-development',
        ]),
      );
      expect(
        read('ios/Runner/Anywhere/LockMessageIntent.swift'),
        startsWith('#if INK_ANYWHERE'),
      );
    });
  });

  group('the native code', () {
    test('does no cryptography, no networking and no logging', () {
      final banned = RegExp(
        r'import (CryptoKit|CommonCrypto|Network|Security)\b|URLSession|'
        r'NWConnection|\bprint\(|NSLog\(|os_log\(|Logger\(|UserDefaults',
      );
      expect(nativeSwift, isNotEmpty);
      for (final file in nativeSwift) {
        expect(
          banned.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    });

    test('never reads the clipboard by itself', () {
      // Text arrives only from the Services pasteboard macOS hands over,
      // or from the system Paste button the person presses.
      for (final file in nativeSwift) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('NSPasteboard.general')));
        expect(source, isNot(contains('UIPasteboard')));
      }
    });

    test('every shared file is built into both apps', () {
      for (final file in swiftIn('apple/Anywhere')) {
        final name = file.uri.pathSegments.last;
        expect(macProject, contains('$name in Sources'), reason: name);
        expect(iosProject, contains('$name in Sources'), reason: name);
      }
      expect(macProject, contains('Anywhere.strings in Resources'));
      expect(iosProject, contains('Anywhere.strings in Resources'));
    });
  });

  test('the native strings are generated from the current .arb files', () {
    for (final MapEntry(key: path, value: content)
        in native_strings.expectedFiles().entries) {
      expect(
        File(path).readAsStringSync(),
        content,
        reason: '$path is stale: run tools/native_strings/apple_strings.dart',
      );
    }
  });
}
