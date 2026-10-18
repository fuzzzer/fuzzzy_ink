import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  Object? answer;

  setUp(() {
    calls = [];
    answer = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupExclusion.channel, (call) async {
      calls.add(call);
      if (answer is Exception) throw answer! as Exception;
      return answer;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupExclusion.channel, null);
  });

  group('BackupExclusion', () {
    test('on iOS and macOS it asks the native side to mark the folder',
        () async {
      await const BackupExclusion(isApplePlatform: true)
          .exclude('/Documents/Bob');

      expect(calls, hasLength(1));
      expect(calls.single.method, 'excludeFromBackup');
      expect(calls.single.arguments, {'path': '/Documents/Bob'});
    });

    test('Android, Windows and Linux are left alone', () async {
      await const BackupExclusion(isApplePlatform: false)
          .exclude('/Documents/Bob');

      expect(calls, isEmpty);
    });

    test('a refused or failed mark never throws', () async {
      answer = false;
      await const BackupExclusion(isApplePlatform: true).exclude('/a');
      answer = PlatformException(code: 'failed');
      await const BackupExclusion(isApplePlatform: true).exclude('/b');

      expect(calls, hasLength(2));
    });

    test('a missing native handler never throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BackupExclusion.channel, null);

      await expectLater(
        const BackupExclusion(isApplePlatform: true).exclude('/a'),
        completes,
      );
    });
  });

  group('VaultFileDataSource', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('vault_backup_exclusion');
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    test('marks the vault, items and temp folders when it creates them',
        () async {
      final vaultPath = path.join(root.path, 'vault');
      final dataSource = VaultFileDataSource(
        vaultDirectoryPath: vaultPath,
        backupExclusion: const BackupExclusion(isApplePlatform: true),
      );

      await dataSource.initDirectories();

      expect(
        calls.map((call) => (call.arguments as Map)['path']),
        [
          vaultPath,
          path.join(vaultPath, 'items'),
          path.join(vaultPath, '.tmp'),
        ],
      );

      calls.clear();
      await dataSource.initDirectories();
      expect(calls, isEmpty, reason: 'existing folders are marked at startup');
    });
  });
}
