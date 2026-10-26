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
  late VaultFileDataSource files;
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
    files = VaultFileDataSource(
      vaultDirectoryPath: VaultFileDataSource.directoryIn(root.path),
      backupExclusion: const BackupExclusion(isApplePlatform: false),
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
    expect(jsonDecode(await metaText())['verificationToken'], 'CQ==');
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
