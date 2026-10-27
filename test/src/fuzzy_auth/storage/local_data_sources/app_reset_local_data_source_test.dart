import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

/// "Erase everything" also removes the sealed files the app keeps and any
/// hand-off copy; nothing else in the support folder is its business.
void main() {
  late Directory support;

  setUp(() {
    support = Directory.systemTemp.createTempSync('app_reset_');
  });

  tearDown(() {
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  File write(String relativePath) => File(path.join(support.path, relativePath))
    ..createSync(recursive: true)
    ..writeAsStringSync('x');

  test('deleteSealedFiles removes sealed_files and handoff only', () async {
    final chatContainer = write('sealed_files/chats/Nino (6f1e9b2c)/a.fuzz');
    final basicsContainer = write('sealed_files/basics/b.jpg.fuzz');
    final handoffCopy = write('handoff/1_0/b.jpg');
    final other = write('other.txt');

    await AppResetLocalDataSource(supportDirectoryPath: support.path)
        .deleteSealedFiles();

    expect(chatContainer.existsSync(), isFalse);
    expect(basicsContainer.existsSync(), isFalse);
    expect(handoffCopy.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('deleteSealedFiles on a fresh install is a no-op', () async {
    await AppResetLocalDataSource(supportDirectoryPath: support.path)
        .deleteSealedFiles();

    expect(support.listSync(), isEmpty);
  });

  group('the rest an erase removes (security review 2026-10-26)', () {
    tearDown(() async {
      if (sl.isRegistered<PreferencesService>()) {
        await sl.unregister<PreferencesService>();
      }
      if (sl.isRegistered<FuzzyLinkHandler>()) {
        await sl.unregister<FuzzyLinkHandler>();
      }
    });

    test(
        'every preference goes, the remembered pairing replies with them, and '
        'the safe-password copy switch is back to its default', () async {
      SharedPreferences.setMockInitialValues({
        'paired_acceptance_6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d': 'Fuzz/AgE',
        'has_seen_onboarding': true,
      });
      final prefs = await SharedPreferences.getInstance();
      sl.safeRegisterSingleton<PreferencesService>(PreferencesService(prefs));
      vaultPasswordCopySetting.value = false;

      await AppResetLocalDataSource(supportDirectoryPath: support.path)
          .clearPreferences();

      expect(prefs.getKeys(), isEmpty);
      expect(vaultPasswordCopySetting.value, isTrue);
    });

    test('a link waiting at the lock screen is dropped', () async {
      final handler = _PendingHandler();
      sl.safeRegisterSingleton<FuzzyLinkHandler>(handler);
      AppResetLocalDataSource(supportDirectoryPath: support.path)
          .discardPendingLink();
      expect(handler.discarded, isTrue);
    });

    test('the next launch is told to compact the database file', () async {
      final marker = AppResetLocalDataSource.compactMarkerIn(support.path);
      expect(marker.existsSync(), isFalse);
      await marker.create(recursive: true);
      expect(
        path.basename(marker.path),
        AppResetLocalDataSource.compactMarkerName,
      );
    });
  });
}

class _PendingHandler implements FuzzyLinkHandler {
  bool discarded = false;

  @override
  void discardPending() => discarded = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
