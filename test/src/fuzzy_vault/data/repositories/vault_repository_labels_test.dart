import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/crypto_core_test_init.dart';

class _MemoryItems extends Mock implements VaultItemLocalDataSource {
  final rows = <String, StoredVaultItem>{};

  @override
  Future<void> saveItem(StoredVaultItem item) async => rows[item.itemId] = item;

  @override
  Future<StoredVaultItem?> getItem(String itemId) async => rows[itemId];

  @override
  Future<List<StoredVaultItem>> getAllItems() async => rows.values.toList();

  @override
  Future<void> deleteItem(String itemId) async => rows.remove(itemId);
}

class _Groups extends Mock implements VaultGroupLocalDataSource {
  @override
  Future<StoredVaultGroup?> getGroup(String groupId) async =>
      StoredVaultGroup()..groupId = groupId;
}

const _master = 'Master-Pass-Word-42!';
const _bank = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _lease = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
const _diary = '1b2c3d4e-5f6a-4b7c-8d9e-0f1a2b3c4d5e';

VaultItem _password(String id, String username, {bool own = false}) =>
    VaultItem(
      metadata: _metadata(id, VaultItemType.password, own: own),
      passwordContent: VaultPasswordContent(
        username: username,
        password: 'hunter2',
      ),
    );

VaultItemMetadata _metadata(
  String id,
  VaultItemType type, {
  bool own = false,
}) =>
    VaultItemMetadata(
      id: id,
      title: 'Title $id',
      type: type,
      groupId: VaultGroupData.generalGroupId,
      tags: const [],
      isFavorite: false,
      hasCustomPassword: own,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      contentVersion: 1,
    );

/// My safe's rows show a username or file name without opening any item:
/// each item's label is sealed on its own under the vault key (final
/// regression 2026-10-26).
void main() {
  setUpAll(initCryptoCoreForTests);

  late Directory root;
  late CryptoCoreService service;
  late VaultCryptoRepository crypto;
  late VaultFileDataSource files;
  late _MemoryItems items;
  late VaultRepository repository;
  late VaultKey key;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('vault_labels_');
    service = CryptoCoreService(storeDirectoryPath: '${root.path}/store');
    final chatAuth = ChatAuthRepository(
      localDataSource: MasterKeyLocalDataSource(),
      cryptoCoreService: service,
    );
    await chatAuth.setUp(_master);
    crypto = VaultCryptoRepository(
      passwordStrengthService: PasswordStrengthService(),
      cryptoCoreService: service,
      chatAuthRepository: chatAuth,
    );
    final metadata =
        (await crypto.initializeVault(_master) as VaultSuccess<VaultMetadata>)
            .data;
    key =
        (await crypto.unlock(_master, metadata) as VaultSuccess<VaultKey>).data;
    files = VaultFileDataSource(
      vaultDirectoryPath: VaultFileDataSource.directoryIn(root.path),
      backupExclusion: const BackupExclusion(isApplePlatform: false),
    );
    items = _MemoryItems();
    repository = VaultRepository(
      itemDataSource: items,
      groupDataSource: _Groups(),
      fileDataSource: files,
      cryptoRepository: crypto,
    );
  });

  tearDown(() async {
    await service.close();
    root.deleteSync(recursive: true);
  });

  Future<List<VaultItemMetadata>> listed() async =>
      (await repository.getAllItems() as VaultSuccess<List<VaultItemMetadata>>)
          .data;

  test('a password shows its username, a file its name, a note nothing',
      () async {
    await repository.createItem(_password(_bank, ' tamar@mail.ge '), key);
    await repository.createItem(
      VaultItem(
        metadata: _metadata(_lease, VaultItemType.file),
        fileContent: const VaultFileContent(
          fileName: 'lease.pdf',
          fileBytes: [1, 2, 3],
        ),
      ),
      key,
    );
    await repository.createItem(
      VaultItem(
        metadata: _metadata(_diary, VaultItemType.note),
        noteContent:
            const VaultNoteContent(delta: [], plainText: 'secret note'),
      ),
      key,
    );

    expect(await repository.readLabels(await listed(), key), {
      _bank: 'tamar@mail.ge',
      _lease: 'lease.pdf',
    });
  });

  test('the label is sealed: neither the username nor the secret on disk',
      () async {
    await repository.createItem(_password(_bank, 'tamar@mail.ge'), key);
    final sealed = await files.readLabel(_bank);
    expect(sealed, isNotNull);
    final text = latin1.decode(sealed!);
    expect(text, isNot(contains('tamar')));
    expect(text, isNot(contains('hunter2')));
  });

  test('a label opens only as its own item, never as the item or another',
      () async {
    await repository.createItem(_password(_bank, 'tamar@mail.ge'), key);
    final sealed = Uint8List.fromList((await files.readLabel(_bank))!);
    // As the item itself: no.
    final asItem = await service.vaultOpen(
      key: key,
      itemId: _bank,
      version: 1,
      blob: sealed,
    );
    expect(asItem, isA<CryptoCoreFailure<Uint8List>>());
    // As another item's label: no.
    expect(
      await crypto.openLabel(sealed, key, itemId: _lease, version: 1),
      isNull,
    );
    // The item's own file never opens as a label.
    final itemFile = Uint8List.fromList((await files.readItem(_bank))!);
    expect(
      await crypto.openLabel(itemFile, key, itemId: _bank, version: 1),
      isNull,
    );
  });

  test('an edit renews the label; an empty username drops it', () async {
    await repository.createItem(_password(_bank, 'old@mail.ge'), key);
    final created =
        (await repository.getItem(_bank, key) as VaultSuccess<VaultItem>).data;
    await repository.updateItem(
      created.copyWith(
        passwordContent: created.passwordContent!.copyWith(
          username: 'new@mail.ge',
        ),
      ),
      key,
    );
    expect(await repository.readLabels(await listed(), key), {
      _bank: 'new@mail.ge',
    });

    final updated =
        (await repository.getItem(_bank, key) as VaultSuccess<VaultItem>).data;
    await repository.updateItem(
      updated.copyWith(
        passwordContent: updated.passwordContent!.copyWith(username: ' '),
      ),
      key,
    );
    expect(await files.readLabel(_bank), isNull);
    expect(await repository.readLabels(await listed(), key), isEmpty);
  });

  test('an item with a password of its own keeps no label', () async {
    await repository.createItem(
      _password(_bank, 'tamar@mail.ge', own: true),
      key,
      customPassword: 'item-only',
    );
    expect(await files.readLabel(_bank), isNull);
    expect(await repository.readLabels(await listed(), key), isEmpty);
  });

  test('a label left a version behind (a stop mid-save) shows the type',
      () async {
    await repository.createItem(_password(_bank, 'tamar@mail.ge'), key);
    items.rows[_bank]!.contentVersion = 3;
    expect(await repository.readLabels(await listed(), key), isEmpty);
  });

  test('deleting the item deletes its label', () async {
    await repository.createItem(_password(_bank, 'tamar@mail.ge'), key);
    await repository.deleteItem(_bank);
    expect(await files.readLabel(_bank), isNull);
  });

  test('a closed key opens no label', () async {
    await repository.createItem(_password(_bank, 'tamar@mail.ge'), key);
    await key.close();
    expect(await repository.readLabels(await listed(), key), isEmpty);
  });
}
