import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The crypto store, the Isar database and the wrapped store key never leave
/// the device through an OS/cloud backup (THREAT_MODEL.md §2.8 / R34 / D-8).
/// These assertions pin the platform files a Dart test cannot exercise.
void main() {
  const domains = ['root', 'file', 'database', 'sharedpref', 'external'];

  group('Android', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('Auto Backup is disabled', () {
      expect(manifest, contains('android:allowBackup="false"'));
    });

    test('API ≤ 30 rules exclude every domain', () {
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      final rules = File('android/app/src/main/res/xml/backup_rules.xml')
          .readAsStringSync();
      expect(rules, isNot(contains('<include')));
      for (final domain in domains) {
        expect(rules, contains('<exclude domain="$domain" path="." />'));
      }
    });

    test('API 31+ rules exclude every domain from backup and transfer', () {
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      final rules =
          File('android/app/src/main/res/xml/data_extraction_rules.xml')
              .readAsStringSync();
      expect(rules, isNot(contains('<include')));
      for (final section in ['cloud-backup', 'device-transfer']) {
        final body = RegExp('<$section[^>]*>(.*?)</$section>', dotAll: true)
            .firstMatch(rules)
            ?.group(1);
        expect(body, isNotNull, reason: '<$section> missing');
        for (final domain in domains) {
          expect(body, contains('<exclude domain="$domain" path="." />'));
        }
      }
    });
  });

  group('iOS / macOS', () {
    test('Application Support is excluded from backups at launch', () {
      for (final path in [
        'ios/Runner/AppDelegate.swift',
        'macos/Runner/MainFlutterWindow.swift',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('.applicationSupportDirectory'), reason: path);
        expect(source, contains('isExcludedFromBackup = true'), reason: path);
        expect(
          source,
          contains('excludeApplicationSupportFromBackup()'),
          reason: path,
        );
      }
    });
  });
}
