import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

/// Links are `https://ink.fuzzzycore.com/<kind>#<payload>` only, claimed by
/// verified App Links on Android and universal links on iOS; the old
/// `fuzzylink://` scheme is gone (another app could claim it, any web page
/// could fire it). These assertions pin the platform files and the link
/// page's verification files to the paths the parser reads.
void main() {
  const host = FuzzyLinkParser.host;
  final paths = FuzzyLinkType.values.map((type) => type.path).toList();
  const appIds = ['com.fuzzzycore.ink', 'com.fuzzzycore.ink.stg'];
  const devAppId = 'com.fuzzzycore.ink.dev';

  String read(String path) => File(path).readAsStringSync();

  test('no platform file registers the fuzzylink scheme any more', () {
    for (final path in [
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
      'macos/Runner/Info.plist',
    ]) {
      final source = read(path);
      expect(source, isNot(contains('fuzzylink')), reason: path);
      expect(source, isNot(contains('CFBundleURLSchemes')), reason: path);
    }
  });

  group('Android', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');

    test('one verified https intent filter for the link host and paths', () {
      final filters = RegExp(
        '<intent-filter android:autoVerify="true">(.*?)</intent-filter>',
        dotAll: true,
      ).allMatches(manifest).toList();
      expect(filters, hasLength(1));

      final filter = filters.single.group(1)!;
      expect(filter, contains('android.intent.action.VIEW'));
      expect(filter, contains('android.intent.category.BROWSABLE'));
      expect(filter, contains('<data android:scheme="https" />'));
      expect(filter, isNot(contains('android:scheme="http"')));
      expect(filter, contains('<data android:host="$host" />'));
      for (final path in paths) {
        expect(filter, contains('<data android:path="$path" />'));
      }
      expect(filter, isNot(contains('pathPrefix')));
      expect(filter, isNot(contains('pathPattern')));
    });

    test("Flutter's own deep linking is off (app_links reads the links)", () {
      expect(
        manifest,
        contains(
          'android:name="flutter_deeplinking_enabled"\n'
          '                android:value="false"',
        ),
      );
    });
  });

  group('iOS', () {
    test('the Runner entitlements claim the link host', () {
      final entitlements = read('ios/Runner/Runner.entitlements');
      expect(
        entitlements,
        contains('<key>com.apple.developer.associated-domains</key>'),
      );
      expect(entitlements, contains('<string>applinks:$host</string>'));
    });

    test('every Runner build configuration, every flavour, signs with them',
        () {
      final project = read('ios/Runner.xcodeproj/project.pbxproj');
      final runnerConfigs = RegExp(
        r'isa = XCBuildConfiguration;(.*?)\n\t\t\};',
        dotAll: true,
      )
          .allMatches(project)
          .map((match) => match.group(1)!)
          .where((body) => body.contains('INFOPLIST_FILE = Runner/Info.plist;'))
          .toList();

      // Debug, Release and Profile for production, staging and development.
      expect(runnerConfigs, hasLength(9));
      for (final body in runnerConfigs) {
        expect(
          body,
          contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
        );
      }
    });

    test("Flutter's own deep linking is off (app_links reads the links)", () {
      expect(
        read('ios/Runner/Info.plist'),
        contains('<key>FlutterDeepLinkingEnabled</key>\n\t<false/>'),
      );
    });
  });

  group('link page (link_site/)', () {
    test(
        'the Apple file names the production app only (security review '
        '2026-10-26) and exactly the link paths', () {
      final json = jsonDecode(
        read('link_site/.well-known/apple-app-site-association'),
      ) as Map<String, dynamic>;
      final details = ((json['applinks'] as Map<String, dynamic>)['details']
              as List<dynamic>)
          .single as Map<String, dynamic>;

      final ids = (details['appIDs'] as List<dynamic>).cast<String>();
      expect(ids, ['7W88HRQFXP.${appIds.first}']);
      final testIds = ((((jsonDecode(
        read(
          'link_site_test_builds/.well-known/'
          'apple-app-site-association',
        ),
      ) as Map<String, dynamic>)['applinks'] as Map<String, dynamic>)['details']
              as List<dynamic>)
          .single as Map<String, dynamic>)['appIDs'] as List<dynamic>;
      expect(testIds, [
        for (final id in [...appIds.skip(1), devAppId]) '7W88HRQFXP.$id',
      ]);

      final components =
          (details['components'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(components.map((c) => c['/']), paths);
      // A link without a payload after # is not the app's.
      for (final component in components) {
        expect(component['#'], '?*');
      }
    });

    test('the Android file names the production package only', () {
      final statements =
          (jsonDecode(read('link_site/.well-known/assetlinks.json'))
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();

      expect(
        statements.map(
          (s) => (s['target'] as Map<String, dynamic>)['package_name'],
        ),
        [appIds.first],
      );
      final testStatements = (jsonDecode(
        read('link_site_test_builds/.well-known/assetlinks.json'),
      ) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        testStatements.map(
          (s) => (s['target'] as Map<String, dynamic>)['package_name'],
        ),
        [...appIds.skip(1), devAppId],
      );
      for (final statement in statements) {
        expect(
          statement['relation'],
          ['delegate_permission/common.handle_all_urls'],
        );
        final target = statement['target'] as Map<String, dynamic>;
        expect(target['namespace'], 'android_app');
        expect(target['sha256_cert_fingerprints'], hasLength(1));
      }
    });

    test('the page runs no script and loads nothing from elsewhere', () {
      final page = read('link_site/index.html');

      expect(page.toLowerCase(), isNot(contains('<script')));
      expect(page, isNot(contains(RegExp(r'\son\w+\s*='))));
      expect(page, contains("default-src 'none'"));
      expect(page, contains('<meta name="referrer" content="no-referrer" />'));
      // Only the store and download buttons point anywhere else.
      final externalReferences = RegExp('(src|href)="(https?:)?//')
          .allMatches(page)
          .map((match) => match.group(1))
          .toList();
      expect(externalReferences, everyElement('href'));
      expect(page, isNot(contains('<link')));
    });
  });
}
