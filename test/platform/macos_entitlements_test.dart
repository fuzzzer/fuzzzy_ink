import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The "find devices on local networks" question a debug build asks on a
/// Mac (QA 2026-10-26) comes from the debug tooling: Debug and Profile
/// builds carry `network.server` so the Dart VM service can listen. Every
/// Release build uses `Release.entitlements`, which has no network
/// entitlement at all (the app is offline), so a shipped app never asks.
void main() {
  final project =
      File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  final release = File('macos/Runner/Release.entitlements').readAsStringSync();

  test('the release entitlements have no network entitlement', () {
    expect(release, isNot(contains('com.apple.security.network')));
    expect(release, contains('com.apple.security.app-sandbox'));
  });

  test(
      'both entitlement files allow printing (the recovery key sheet goes '
      'to the system print dialog; sandboxed without it, macOS answers '
      '"This application does not support printing")', () {
    final debug =
        File('macos/Runner/DebugProfile.entitlements').readAsStringSync();
    for (final entitlements in [release, debug]) {
      expect(entitlements, contains('<key>com.apple.security.print</key>'));
    }
  });

  test('every Release configuration of every flavour uses them', () {
    final configs = RegExp(
      'isa = XCBuildConfiguration;(.*?)name = "?([^";]+)"?;',
      dotAll: true,
    ).allMatches(project);
    final releases = [
      for (final config in configs)
        if (config.group(2)!.startsWith('Release') &&
            config.group(1)!.contains('CODE_SIGN_ENTITLEMENTS'))
          config,
    ];
    expect(releases, hasLength(3), reason: 'development, staging, production');
    for (final config in releases) {
      expect(
        config.group(1),
        contains('CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;'),
        reason: config.group(2),
      );
    }
  });
}
