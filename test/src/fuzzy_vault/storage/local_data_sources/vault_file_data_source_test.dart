import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;

  VaultFileDataSource dataSourceAt(String vaultPath) => VaultFileDataSource(
        vaultDirectoryPath: vaultPath,
        backupExclusion: const BackupExclusion(isApplePlatform: false),
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vault_file_data_source');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  group('clearAll', () {
    test('deletes the dedicated vault folder', () async {
      final vaultPath = VaultFileDataSource.directoryIn(root.path);
      final dataSource = dataSourceAt(vaultPath);
      await dataSource.writeMetaAtomic(utf8.encode('{}'));
      await dataSource.writeItemAtomic('a', [1, 2, 3]);
      await File(path.join(root.path, 'neighbour.txt')).writeAsString('keep');

      await dataSource.clearAll();

      expect(Directory(vaultPath).existsSync(), isFalse);
      expect(File(path.join(root.path, 'neighbour.txt')).existsSync(), isTrue);
    });

    test('refuses a folder that is not the vault folder, deleting nothing',
        () async {
      final documents = Directory(path.join(root.path, 'Documents'));
      await File(path.join(documents.path, 'Work', 'budget.xlsx'))
          .create(recursive: true);

      for (final vaultPath in [
        documents.path,
        '${documents.path}${Platform.pathSeparator}',
        path.join(documents.path, 'vault', '..'),
        path.join(documents.path, 'vaults'),
      ]) {
        await expectLater(
          dataSourceAt(vaultPath).clearAll(),
          throwsA(isA<StateError>()),
          reason: vaultPath,
        );
      }

      expect(
        File(path.join(documents.path, 'Work', 'budget.xlsx')).existsSync(),
        isTrue,
      );
    });
  });

  test('the export working folder sits inside the vault folder', () {
    final vaultPath = VaultFileDataSource.directoryIn(root.path);

    expect(
      dataSourceAt(vaultPath).exportTmpDirectoryPath,
      path.join(vaultPath, '.tmp_export'),
    );
  });

  test('a vault mid-move neither opens nor accepts writes', () async {
    final vaultPath = VaultFileDataSource.directoryIn(root.path);
    final dataSource = dataSourceAt(vaultPath);
    await dataSource.writeMetaAtomic(utf8.encode('{}'));
    await File(path.join(vaultPath, VaultFileDataSource.migrationMarkerName))
        .writeAsString('');

    await expectLater(
      dataSource.readMeta(),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      dataSource.writeMetaAtomic(utf8.encode('{"new": true}')),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      dataSource.writeItemAtomic('a', [1]),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      dataSource.deleteItem('a'),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      await File(path.join(vaultPath, 'vault.meta')).readAsString(),
      '{}',
    );
  });

  test(
      'a move that failed before its marker keeps the vault closed: '
      'nothing opens and no new vault can be written', () async {
    final vaultPath = VaultFileDataSource.directoryIn(root.path);
    final dataSource = VaultFileDataSource(
      vaultDirectoryPath: vaultPath,
      backupExclusion: const BackupExclusion(isApplePlatform: false),
      moveFailed: true,
    );

    await expectLater(
      dataSource.readMeta(),
      throwsA(isA<VaultMoveUnfinishedException>()),
    );
    await expectLater(
      dataSource.writeMetaAtomic(utf8.encode('{"new": true}')),
      throwsA(isA<VaultMoveUnfinishedException>()),
    );
    await expectLater(
      dataSource.writeItemAtomic('a', [1]),
      throwsA(isA<VaultMoveUnfinishedException>()),
    );
    expect(File(path.join(vaultPath, 'vault.meta')).existsSync(), isFalse);
  });
}
