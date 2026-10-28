import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

import '../../fuzz_anywhere_fakes.dart';

void main() {
  setUpAll(registerAnywhereFallbacks);

  late AnywhereHarness app;

  setUp(() => app = AnywhereHarness());
  tearDown(() => app.dispose());

  group('the switches', () {
    test('nothing stored reads as off, with Lock again on', () async {
      expect(
        await app.repository.readSettings(),
        FuzzAnywhereSettings.standard,
      );
      expect(FuzzAnywhereSettings.standard.isOn, isFalse);
      expect(FuzzAnywhereSettings.standard.locksAgainAfterUse, isTrue);
    });

    test('are kept sealed and read back', () async {
      const on = FuzzAnywhereSettings(isOn: true, locksAgainAfterUse: false);
      expect(
        await app.repository.writeSettings(on),
        isA<CryptoCoreSuccess<void>>(),
      );

      final stored =
          app.storage.blobs[FuzzAnywhereLocalDataSource.settingsKey]!;
      expect(latin1.decode(stored), isNot(contains('"on"')));
      expect(await app.repository.readSettings(), on);
    });

    test('an edited blob, or one plainly written, reads as off', () async {
      app.storage.blobs[FuzzAnywhereLocalDataSource.settingsKey] =
          Uint8List.fromList(utf8.encode('{"on":true,"lockAgain":false}'));
      expect(
        await app.repository.readSettings(),
        FuzzAnywhereSettings.standard,
      );

      app.storeSettings(
        const FuzzAnywhereSettings(isOn: true, locksAgainAfterUse: true),
      );
      app.storage.blobs[FuzzAnywhereLocalDataSource.settingsKey]!.last ^= 1;
      expect(
        await app.repository.readSettings(),
        FuzzAnywhereSettings.standard,
      );
    });
  });

  group('the person per app', () {
    test('keeps the latest per app, newest first, at most 32 apps', () async {
      for (var i = 0; i < 40; i++) {
        await app.repository.rememberPerson(appId: 'app.$i', personId: ninoId);
      }
      await app.repository.rememberPerson(appId: 'app.39', personId: momId);

      expect(await app.repository.lastPersonFor('app.39'), momId);
      expect(await app.repository.lastPersonFor('app.8'), ninoId);
      expect(await app.repository.lastPersonFor('app.7'), isNull);
    });

    test(
        'refuses an app id that is empty, too long or has control '
        'characters', () async {
      for (final appId in ['', 'a' * 201, 'com.app\n']) {
        expect(FuzzAnywhereSettingsRepository.isAppId(appId), isFalse);
        expect(
          await app.repository.rememberPerson(appId: appId, personId: ninoId),
          isA<CryptoCoreFailure<void>>(),
        );
      }
      expect(app.storage.blobs, isEmpty);
      expect(FuzzAnywhereSettingsRepository.isAppId('com.whatsapp'), isTrue);
    });
  });
}
