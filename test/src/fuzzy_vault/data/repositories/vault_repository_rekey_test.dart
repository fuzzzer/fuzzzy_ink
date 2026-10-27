import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

class MockVaultItemLocalDataSource extends Mock
    implements VaultItemLocalDataSource {}

class MockVaultGroupLocalDataSource extends Mock
    implements VaultGroupLocalDataSource {}

class MockVaultCryptoRepository extends Mock implements VaultCryptoRepository {}

class MockVaultKey extends Mock implements VaultKey {}

/// The real files, with one step that fails on demand.
class _FlakyFiles extends VaultFileDataSource {
  _FlakyFiles({required super.vaultDirectoryPath})
      : super(backupExclusion: const BackupExclusion(isApplePlatform: false));

  bool failStagingLabel = false;
  bool failDeletingUnmovedLabels = false;

  @override
  Future<void> stageRekeyedLabel(String itemId, List<int> bytes) async {
    if (failStagingLabel) throw const FileSystemException('disk full');
    await super.stageRekeyedLabel(itemId, bytes);
  }

  @override
  Future<void> deleteUnmovedLabels() async {
    if (failDeletingUnmovedLabels) {
      throw const FileSystemException('not permitted');
    }
    await super.deleteUnmovedLabels();
  }
}

StoredVaultItem _item(String id, {bool ownPassword = false}) =>
    StoredVaultItem()
      ..itemId = id
      ..title = id
      ..groupId = VaultGroupData.generalGroupId
      ..type = VaultItemType.note
      ..tags = const []
      ..isFavorite = false
      ..hasCustomPassword = ownPassword
      ..createdAt = DateTime(2026)
      ..updatedAt = DateTime(2026)
      ..contentVersion = 1;

/// The safe's move to a new key when it gets its own password (security
/// review 2026-10-26): every item is re-sealed before one rename commits.
void main() {
  late Directory root;
  late _FlakyFiles files;
  late MockVaultItemLocalDataSource items;
  late MockVaultCryptoRepository crypto;
  late VaultRepository repository;
  final previous = MockVaultKey();
  final next = MockVaultKey();
  final metadata = VaultMetadata(
    vaultId: 'vault-1',
    verificationToken: base64Encode([9]),
    createdAt: DateTime(2026),
    lastUnlockedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(MockVaultKey());
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vault_rekey');
    files = _FlakyFiles(
      vaultDirectoryPath: VaultFileDataSource.directoryIn(root.path),
    );
    items = MockVaultItemLocalDataSource();
    crypto = MockVaultCryptoRepository();
    repository = VaultRepository(
      itemDataSource: items,
      groupDataSource: MockVaultGroupLocalDataSource(),
      fileDataSource: files,
      cryptoRepository: crypto,
    );
    await files.writeMetaAtomic(utf8.encode('old meta'));
    await files.writeItemAtomic('a', [1]);
    await files.writeItemAtomic('b', [2]);
    when(
      () => crypto.reseal(
        from: previous,
        to: next,
        itemId: any(named: 'itemId'),
        version: 1,
        blob: any(named: 'blob'),
      ),
    ).thenAnswer((invocation) async {
      final blob = invocation.namedArguments[#blob] as Uint8List;
      return VaultSuccess(Uint8List.fromList([blob.single + 10]));
    });
    when(
      () => crypto.resealLabel(
        from: previous,
        to: next,
        itemId: any(named: 'itemId'),
        version: 1,
        blob: any(named: 'blob'),
      ),
    ).thenAnswer((invocation) async {
      final blob = invocation.namedArguments[#blob] as Uint8List;
      return VaultSuccess(Uint8List.fromList([blob.single + 10]));
    });
  });

  tearDown(() => root.delete(recursive: true));

  Future<String> metaText() async => utf8.decode((await files.readMeta())!);

  test('every item moves, then the new metadata is in place', () async {
    when(items.getAllItems).thenAnswer((_) async => [_item('a'), _item('b')]);
    var committedBefore = false;
    final res = await repository.rekey(
      previous: previous,
      key: next,
      metadata: metadata,
      beforeCommit: () async {
        committedBefore = await files.readItem('a') != null &&
            (await files.readItem('a'))!.single == 1;
        return null;
      },
    );
    expect(res, isA<VaultSuccess<void>>());
    expect(committedBefore, isTrue, reason: 'the old items until the commit');
    expect(await files.readItem('a'), [11]);
    expect(await files.readItem('b'), [12]);
    final meta = jsonDecode(await metaText()) as Map<String, dynamic>;
    expect(meta['verificationToken'], 'CQ==');
  });

  test(
      "the rows' labels move with their items; one that does not open is "
      'dropped, never stopping the move (final regression 2026-10-26)',
      () async {
    when(items.getAllItems).thenAnswer((_) async => [_item('a'), _item('b')]);
    await files.writeLabelAtomic('a', [5]);
    await files.writeLabelAtomic('b', [6]);
    when(
      () => crypto.resealLabel(
        from: previous,
        to: next,
        itemId: 'b',
        version: 1,
        blob: any(named: 'blob'),
      ),
    ).thenAnswer(
      (_) async => const VaultFailure(VaultFailureType.fileCorrupted),
    );

    final res = await repository.rekey(
      previous: previous,
      key: next,
      metadata: metadata,
    );
    expect(res, isA<VaultSuccess<void>>());
    expect(await files.readItem('a'), [11]);
    expect(await files.readLabel('a'), [15]);
    expect(await files.readLabel('b'), isNull);
  });

  group('no label stays under the old key (security review 2026-10-26)', () {
    Future<VaultResponse<void>> move() => repository.rekey(
          previous: previous,
          key: next,
          metadata: metadata,
        );

    test('when moving it throws', () async {
      when(items.getAllItems).thenAnswer((_) async => [_item('a'), _item('b')]);
      await files.writeLabelAtomic('a', [5]);
      await files.writeLabelAtomic('b', [6]);
      when(
        () => crypto.resealLabel(
          from: previous,
          to: next,
          itemId: 'b',
          version: 1,
          blob: any(named: 'blob'),
        ),
      ).thenThrow(StateError('bridge'));

      expect(await move(), isA<VaultSuccess<void>>());
      expect(await files.readItem('b'), [12]);
      expect(await files.readLabel('a'), [15]);
      expect(await files.readLabel('b'), isNull);
    });

    test('when writing its moved copy fails', () async {
      when(items.getAllItems).thenAnswer((_) async => [_item('a')]);
      await files.writeLabelAtomic('a', [5]);
      files.failStagingLabel = true;

      expect(await move(), isA<VaultSuccess<void>>());
      expect(await files.readItem('a'), [11]);
      expect(await files.readLabel('a'), isNull);
    });

    test("when its item's file is missing", () async {
      when(items.getAllItems).thenAnswer((_) async => [_item('a'), _item('c')]);
      await files.writeLabelAtomic('c', [7]);

      expect(await move(), isA<VaultSuccess<void>>());
      expect(await files.readLabel('c'), isNull);
    });

    test('when it has no row (a create that stopped before its row)', () async {
      when(items.getAllItems).thenAnswer((_) async => [_item('a')]);
      await files.writeLabelAtomic('a', [5]);
      await files.writeLabelAtomic('orphan', [8]);

      expect(await move(), isA<VaultSuccess<void>>());
      expect(await files.readLabel('a'), [15]);
      expect(await files.readLabel('orphan'), isNull);
    });

    test(
        'when such a label cannot be deleted, the move stops before the '
        'recovery copy is touched and the old vault stays whole', () async {
      when(items.getAllItems).thenAnswer((_) async => [_item('a')]);
      await files.writeLabelAtomic('a', [5]);
      files.failDeletingUnmovedLabels = true;
      var recoveryCopyTouched = false;

      final res = await repository.rekey(
        previous: previous,
        key: next,
        metadata: metadata,
        beforeCommit: () async {
          recoveryCopyTouched = true;
          return null;
        },
      );
      expect((res as VaultFailure).type, VaultFailureType.storageWriteError);
      expect(recoveryCopyTouched, isFalse);
      expect(await metaText(), 'old meta');
      expect(await files.readItem('a'), [1]);
      expect(await files.readLabel('a'), [5]);
      expect(
        root
            .listSync(recursive: true)
            .where((entity) => entity.path.endsWith('.rekey')),
        isEmpty,
      );
    });
  });

  test('a move that stops before the commit leaves the labels as they were',
      () async {
    when(items.getAllItems).thenAnswer((_) async => [_item('a')]);
    await files.writeLabelAtomic('a', [5]);
    final res = await repository.rekey(
      previous: previous,
      key: next,
      metadata: metadata,
      beforeCommit: () async => VaultFailureType.storageWriteError,
    );
    expect(res, isA<VaultFailure<void>>());
    expect(await files.readLabel('a'), [5]);
    expect(
      root
          .listSync(recursive: true)
          .where((entity) => entity.path.endsWith('.rekey')),
      isEmpty,
    );
  });

  test('an item that does not open stops the move; the old vault stays',
      () async {
    when(items.getAllItems).thenAnswer((_) async => [_item('a'), _item('b')]);
    when(
      () => crypto.reseal(
        from: previous,
        to: next,
        itemId: 'b',
        version: 1,
        blob: any(named: 'blob'),
      ),
    ).thenAnswer(
      (_) async => const VaultFailure(VaultFailureType.fileCorrupted),
    );
    final res = await repository.rekey(
      previous: previous,
      key: next,
      metadata: metadata,
    );
    expect((res as VaultFailure).type, VaultFailureType.fileCorrupted);
    expect(await metaText(), 'old meta');
    expect(await files.readItem('a'), [1]);
    expect(await files.readItem('b'), [2]);
  });

  test('a failure before the commit (the recovery copy) stops the move',
      () async {
    when(items.getAllItems).thenAnswer((_) async => [_item('a')]);
    final res = await repository.rekey(
      previous: previous,
      key: next,
      metadata: metadata,
      beforeCommit: () async => VaultFailureType.storageWriteError,
    );
    expect((res as VaultFailure).type, VaultFailureType.storageWriteError);
    expect(await metaText(), 'old meta');
    expect(await files.readItem('a'), [1]);
  });

  test('an item with a password of its own cannot be moved', () async {
    when(items.getAllItems)
        .thenAnswer((_) async => [_item('a', ownPassword: true)]);
    final res = await repository.rekey(
      previous: previous,
      key: next,
      metadata: metadata,
    );
    expect(res, isA<VaultFailure<void>>());
    expect(await metaText(), 'old meta');
    verifyNever(
      () => crypto.reseal(
        from: any(named: 'from'),
        to: any(named: 'to'),
        itemId: any(named: 'itemId'),
        version: any(named: 'version'),
        blob: any(named: 'blob'),
      ),
    );
  });
}
