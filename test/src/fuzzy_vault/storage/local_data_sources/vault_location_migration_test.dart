import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class _MockItems extends Mock implements VaultItemLocalDataSource {}

class _MockGroups extends Mock implements VaultGroupLocalDataSource {}

class _MockCrypto extends Mock implements VaultCryptoRepository {}

/// A sealed-blob stand-in: what matters to the move is the `FUZZ` magic.
List<int> _blob(String body) =>
    [...utf8.encode('FUZZ'), 1, 0x20, ...utf8.encode(body)];

List<int> _meta(String vaultId) => utf8.encode(
      jsonEncode({
        'vaultId': vaultId,
        'verificationToken': 'wrapped-key-$vaultId',
        'createdAt': '2026-01-01T00:00:00.000',
        'lastUnlockedAt': '2026-01-01T00:00:00.000',
        'autoLockMinutes': 5,
        'customDirectoryPath': null,
      }),
    );

void main() {
  late Directory root;
  late String documents;
  late String support;
  late String vault;

  String inDocuments(String relative) => path.join(documents, relative);
  String inVault(String relative) => path.join(vault, relative);

  Future<void> write(String filePath, List<int> bytes) async {
    await File(filePath).parent.create(recursive: true);
    await File(filePath).writeAsBytes(bytes, flush: true);
  }

  VaultFileDataSource dataSource() => VaultFileDataSource(
        vaultDirectoryPath: vault,
        backupExclusion: const BackupExclusion(isApplePlatform: false),
      );

  VaultLocationMigration migration({bool preferRename = true}) =>
      VaultLocationMigration(
        legacyDirectoryPath: documents,
        vaultDataSource: dataSource(),
        preferRename: preferRename,
      );

  Future<void> seedLegacyVault() async {
    await write(inDocuments('vault.meta'), _meta('old'));
    await write(inDocuments('items/a.vault'), _blob('item a'));
    await write(inDocuments('items/b.vault'), _blob('item b'));
    await write(inDocuments('.tmp/vault.meta.tmp'), _meta('half'));
    await write(inDocuments('.tmp/c.vault.tmp'), _blob('half c'));
    await Directory(inDocuments('.tmp_export')).create();
  }

  Future<void> expectVaultMoved() async {
    expect(await File(inVault('vault.meta')).readAsBytes(), _meta('old'));
    expect(await File(inVault('items/a.vault')).readAsBytes(), _blob('item a'));
    expect(await File(inVault('items/b.vault')).readAsBytes(), _blob('item b'));
    expect(
      File(inVault(VaultFileDataSource.migrationMarkerName)).existsSync(),
      isFalse,
    );
    for (final leftover in ['vault.meta', 'items', '.tmp', '.tmp_export']) {
      expect(
        FileSystemEntity.typeSync(inDocuments(leftover)),
        FileSystemEntityType.notFound,
        reason: leftover,
      );
    }
    final tmpLeftovers = Directory(inVault('.tmp')).listSync();
    expect(tmpLeftovers, isEmpty);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vault_location_migration');
    documents = path.join(root.path, 'Documents');
    support = path.join(root.path, 'Application Support');
    vault = VaultFileDataSource.directoryIn(support);
    await Directory(documents).create();
    await Directory(support).create();
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('the vault folder is a dedicated folder inside the support directory',
      () {
    expect(vault, path.join(support, 'vault'));
  });

  test('fresh install: nothing to move, nothing created', () async {
    await write(inDocuments('My notes.txt'), utf8.encode('mine'));

    expect(await migration().run(), VaultLocationMigrationResult.nothingToMove);

    expect(Directory(vault).existsSync(), isFalse);
    expect(Directory(documents).listSync().map((e) => path.basename(e.path)), [
      'My notes.txt',
    ]);
  });

  test('an existing vault is moved and its old files are removed', () async {
    await seedLegacyVault();

    expect(await migration().run(), VaultLocationMigrationResult.moved);

    await expectVaultMoved();
    expect(await dataSource().readMeta(), _meta('old'));
    expect(await dataSource().readItem('a'), _blob('item a'));
  });

  test('across volumes the copy path moves the vault the same way', () async {
    await seedLegacyVault();

    expect(
      await migration(preferRename: false).run(),
      VaultLocationMigrationResult.moved,
    );

    await expectVaultMoved();
  });

  test('foreign files in Documents, items/ and .tmp/ are left untouched',
      () async {
    await seedLegacyVault();
    await write(inDocuments('items/photo.jpg'), utf8.encode('jpeg'));
    await write(inDocuments('items/not-ours.vault'), utf8.encode('plain text'));
    await write(inDocuments('.tmp/draft.txt'), utf8.encode('draft'));
    await write(inDocuments('Work/budget.xlsx'), utf8.encode('budget'));

    expect(await migration().run(), VaultLocationMigrationResult.moved);

    expect(File(inVault('vault.meta')).existsSync(), isTrue);
    expect(File(inVault('items/a.vault')).existsSync(), isTrue);
    expect(File(inVault('items/not-ours.vault')).existsSync(), isFalse);
    expect(await File(inDocuments('items/photo.jpg')).readAsString(), 'jpeg');
    expect(
      await File(inDocuments('items/not-ours.vault')).readAsString(),
      'plain text',
    );
    expect(await File(inDocuments('.tmp/draft.txt')).readAsString(), 'draft');
    expect(
      await File(inDocuments('Work/budget.xlsx')).readAsString(),
      'budget',
    );
    expect(File(inDocuments('items/a.vault')).existsSync(), isFalse);
    expect(File(inDocuments('.tmp/vault.meta.tmp')).existsSync(), isFalse);
    expect(File(inDocuments('.tmp/c.vault.tmp')).existsSync(), isFalse);
  });

  test('a vault.meta that is not the vault’s own starts no move', () async {
    await write(
      inDocuments('vault.meta'),
      utf8.encode('{"something": "else"}'),
    );
    await write(inDocuments('items/a.vault'), _blob('item a'));

    expect(await migration().run(), VaultLocationMigrationResult.nothingToMove);

    expect(File(inDocuments('vault.meta')).existsSync(), isTrue);
    expect(File(inDocuments('items/a.vault')).existsSync(), isTrue);
    expect(Directory(vault).existsSync(), isFalse);
  });

  test('a vault already in the private folder is never overwritten', () async {
    await seedLegacyVault();
    await write(inVault('vault.meta'), _meta('new'));
    await write(inVault('items/a.vault'), _blob('new item a'));

    expect(await migration().run(), VaultLocationMigrationResult.keptExisting);

    expect(await File(inVault('vault.meta')).readAsBytes(), _meta('new'));
    expect(
      await File(inVault('items/a.vault')).readAsBytes(),
      _blob('new item a'),
    );
    expect(File(inVault('items/b.vault')).existsSync(), isFalse);
    expect(await File(inDocuments('vault.meta')).readAsBytes(), _meta('old'));
    expect(File(inDocuments('items/a.vault')).existsSync(), isTrue);
  });

  test(
      'an interrupted move resumes: half-done files, stale copy, meta still old',
      () async {
    // The state a kill leaves: marker written, item a renamed into place,
    // item b copied but its source not yet deleted, a stray copy in .tmp,
    // vault.meta not moved yet.
    await seedLegacyVault();
    await dataSource().initDirectories();
    await write(inVault(VaultFileDataSource.migrationMarkerName), []);
    await File(inDocuments('items/a.vault')).rename(inVault('items/a.vault'));
    await File(inDocuments('items/b.vault')).copy(inVault('items/b.vault'));
    await write(
      inVault('.tmp/vault.meta.migrating'),
      _meta('old').sublist(0, 5),
    );

    await expectLater(
      dataSource().readMeta(),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      dataSource().writeMetaAtomic(_meta('replacement')),
      throwsA(isA<FileSystemException>()),
    );

    expect(await migration().run(), VaultLocationMigrationResult.moved);

    await expectVaultMoved();
  });

  test('a move that fails keeps every file and resumes at the next start',
      () async {
    await seedLegacyVault();
    // A folder where item b should land makes this run fail mid-way.
    await Directory(inVault('items/b.vault')).create(recursive: true);

    expect(await migration().run(), VaultLocationMigrationResult.failed);

    expect(
      File(inVault(VaultFileDataSource.migrationMarkerName)).existsSync(),
      isTrue,
    );
    expect(await File(inDocuments('vault.meta')).readAsBytes(), _meta('old'));
    expect(
      await File(inDocuments('items/b.vault')).readAsBytes(),
      _blob('item b'),
    );
    final itemA = File(inVault('items/a.vault')).existsSync()
        ? File(inVault('items/a.vault'))
        : File(inDocuments('items/a.vault'));
    expect(await itemA.readAsBytes(), _blob('item a'));
    await expectLater(
      dataSource().writeMetaAtomic(_meta('replacement')),
      throwsA(isA<FileSystemException>()),
      reason: 'no new vault can be created over a half-moved one',
    );

    await Directory(inVault('items/b.vault')).delete();
    expect(await migration().run(), VaultLocationMigrationResult.moved);

    await expectVaultMoved();
  });

  test(
    'an old vault.meta that cannot be read: the move fails, the vault '
    'stays closed and no new vault is made; a later start moves it',
    () async {
      await seedLegacyVault();
      final legacyMeta = inDocuments('vault.meta');
      await Process.run('chmod', ['000', legacyMeta]);
      addTearDown(() => Process.run('chmod', ['644', legacyMeta]));

      final result = await migration().run();
      expect(result, VaultLocationMigrationResult.failed);
      expect(
        File(inVault(VaultFileDataSource.migrationMarkerName)).existsSync(),
        isFalse,
      );

      // What dependency injection registers after a failed move.
      final repository = VaultRepository(
        itemDataSource: _MockItems(),
        groupDataSource: _MockGroups(),
        fileDataSource: VaultFileDataSource(
          vaultDirectoryPath: vault,
          backupExclusion: const BackupExclusion(isApplePlatform: false),
          moveFailed: result == VaultLocationMigrationResult.failed,
        ),
        cryptoRepository: _MockCrypto(),
      );
      final read = await repository.getMetadata();
      expect(
        read,
        isA<VaultFailure<VaultMetadata>>().having(
          (failure) => failure.type,
          'type',
          VaultFailureType.vaultMoveUnfinished,
        ),
      );
      final created = await repository.saveMetadata(
        VaultMetadata(
          vaultId: 'new',
          verificationToken: 'new',
          createdAt: DateTime(2026),
          lastUnlockedAt: DateTime(2026),
          autoLockMinutes: 5,
        ),
      );
      expect(created, isA<VaultFailure<void>>());
      expect(File(inVault('vault.meta')).existsSync(), isFalse);

      // The next start, with the file readable again, finishes the move.
      await Process.run('chmod', ['644', legacyMeta]);
      expect(await migration().run(), VaultLocationMigrationResult.moved);
      await expectVaultMoved();
    },
    skip: Platform.isWindows ? 'chmod is POSIX only' : false,
  );

  test('a second start after the move does nothing', () async {
    await seedLegacyVault();
    expect(await migration().run(), VaultLocationMigrationResult.moved);

    expect(await migration().run(), VaultLocationMigrationResult.nothingToMove);

    await expectVaultMoved();
  });

  test('the documents directory itself is never treated as a vault to move',
      () async {
    await write(inDocuments('vault.meta'), _meta('old'));
    final sameFolder = VaultLocationMigration(
      legacyDirectoryPath: documents,
      vaultDataSource: VaultFileDataSource(
        vaultDirectoryPath: documents,
        backupExclusion: const BackupExclusion(isApplePlatform: false),
      ),
    );

    expect(await sameFolder.run(), VaultLocationMigrationResult.nothingToMove);
    expect(File(inDocuments('vault.meta')).existsSync(), isTrue);
  });
}
