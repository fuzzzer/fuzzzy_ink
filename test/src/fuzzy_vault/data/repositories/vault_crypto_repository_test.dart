import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

import '../../../../helpers/crypto_core_test_init.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _master = 'Master-Pass-Word-42!';
const _password = 'Correct-Horse-Battery-9!';
const _newPassword = 'Staple-Orange-Kettle-7?';
const _customPassword = 'item-only';
const _itemId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _otherItemId = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';

VaultFailureType _failureOf(VaultResponse<dynamic> res) =>
    (res as VaultFailure).type;

VaultMetadata _metadataOf(VaultResponse<VaultMetadata> res) =>
    (res as VaultSuccess<VaultMetadata>).data;

VaultKey _keyOf(VaultResponse<VaultKey> res) =>
    (res as VaultSuccess<VaultKey>).data;

Uint8List _bytesOf(VaultResponse<Uint8List> res) =>
    (res as VaultSuccess<Uint8List>).data;

VaultDecryptedContent _openedOf(VaultResponse<VaultDecryptedContent> res) =>
    (res as VaultSuccess<VaultDecryptedContent>).data;

const _content = VaultPasswordContent(
  username: 'alice',
  password: 'hunter2',
  url: 'https://example.com',
  notes: 'a note',
);

void main() {
  setUpAll(initCryptoCoreForTests);

  late Directory storeDir;
  late CryptoCoreService service;
  late VaultCryptoRepository repository;
  late ChatAuthRepository chatAuthRepository;
  late CryptoCoreMasterKeySetup masterSetup;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storeDir = Directory.systemTemp.createTempSync('vault_crypto_repo_');
    service = CryptoCoreService(storeDirectoryPath: storeDir.path);
    chatAuthRepository = ChatAuthRepository(
      localDataSource: MasterKeyLocalDataSource(),
      cryptoCoreService: service,
    );
    final setUpRes = await chatAuthRepository.setUp(_master);
    expect(setUpRes, isA<CryptoCoreSuccess<CryptoCoreMasterKeySetup>>());
    masterSetup =
        (setUpRes as CryptoCoreSuccess<CryptoCoreMasterKeySetup>).data;
    repository = VaultCryptoRepository(
      passwordStrengthService: PasswordStrengthService(),
      cryptoCoreService: service,
      chatAuthRepository: chatAuthRepository,
    );
  });

  tearDown(() async {
    await service.close();
    if (storeDir.existsSync()) storeDir.deleteSync(recursive: true);
  });

  Future<Uint8List> seal(
    VaultKey key, {
    int version = 1,
    String? custom,
  }) async =>
      _bytesOf(
        await repository.encryptContent(
          _content,
          key,
          itemId: _itemId,
          version: version,
          customPassword: custom,
        ),
      );

  Future<VaultResponse<VaultDecryptedContent>> open(
    Uint8List sealed,
    VaultKey key, {
    String itemId = _itemId,
    int version = 1,
    String? custom,
  }) =>
      repository.decryptContent(
        sealed,
        key,
        VaultItemType.password,
        itemId: itemId,
        version: version,
        customPassword: custom,
      );

  group('a vault the master password opens (the default)', () {
    test(
        'init → the master password opens it; the key sits under the master '
        'key, not under a password', () async {
      final metadata = _metadataOf(await repository.initializeVault(_master));
      final wrapped = base64Decode(metadata.verificationToken);
      expect(wrapped.length, 78, reason: '0x20 blob: 6 + 24 + 32 + 16');
      expect(wrapped.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x20]);
      expect(
        (repository.usesOwnPassword(metadata) as VaultSuccess<bool>).data,
        isFalse,
      );

      final key = _keyOf(await repository.unlock(_master, metadata));
      final sealed = await seal(key);
      expect(
        utf8.decode(sealed, allowMalformed: true),
        isNot(contains('hunter2')),
      );
      expect(
        (_openedOf(await open(sealed, key)).content as VaultPasswordContent)
            .password,
        'hunter2',
      );
      expect(
        _failureOf(await repository.unlock('wrong', metadata)),
        VaultFailureType.incorrectMasterPassword,
      );
      expect(
        _failureOf(await repository.initializeVault('wrong')),
        VaultFailureType.incorrectMasterPassword,
      );
      await key.close();
      key.dispose();
    });

    test(
        'an item opens only as itself, at its version or one ahead '
        '(security review 2026-10-22)', () async {
      final metadata = _metadataOf(await repository.initializeVault(_master));
      final key = _keyOf(await repository.unlock(_master, metadata));
      final sealed = await seal(key, version: 4);

      expect(_openedOf(await open(sealed, key, version: 4)).version, 4);
      // The index one behind the file (a stop between the two writes).
      expect(_openedOf(await open(sealed, key, version: 3)).version, 4);
      // An older copy put back where version 5 is recorded.
      expect(
        _failureOf(await open(sealed, key, version: 5)),
        VaultFailureType.decryptionFailed,
      );
      // Copied over another item.
      expect(
        _failureOf(await open(sealed, key, itemId: _otherItemId, version: 4)),
        VaultFailureType.decryptionFailed,
      );
      await key.close();
      key.dispose();
    });

    test('own password and back: the same key, every item still opens',
        () async {
      final metadata = _metadataOf(await repository.initializeVault(_master));
      final key = _keyOf(await repository.unlock(_master, metadata));
      final sealed = await seal(key);
      await key.close();
      key.dispose();

      expect(
        _failureOf(
          await repository.useOwnPassword(
            masterPassword: _master,
            newPassword: 'abc',
            metadata: metadata,
          ),
        ),
        VaultFailureType.weakPassword,
      );
      expect(
        _failureOf(
          await repository.useOwnPassword(
            masterPassword: 'wrong',
            newPassword: _password,
            metadata: metadata,
          ),
        ),
        VaultFailureType.incorrectMasterPassword,
      );
      final own = _metadataOf(
        await repository.useOwnPassword(
          masterPassword: _master,
          newPassword: _password,
          metadata: metadata,
        ),
      );
      expect(
        (repository.usesOwnPassword(own) as VaultSuccess<bool>).data,
        isTrue,
      );
      expect(
        _failureOf(await repository.unlock(_master, own)),
        VaultFailureType.incorrectMasterPassword,
        reason: 'the master password no longer opens it',
      );
      final ownKey = _keyOf(await repository.unlock(_password, own));
      expect(_openedOf(await open(sealed, ownKey)).version, 1);
      await ownKey.close();
      ownKey.dispose();

      final back = _metadataOf(
        await repository.useMasterPassword(
          vaultPassword: _password,
          masterPassword: _master,
          metadata: own,
        ),
      );
      expect(
        (repository.usesOwnPassword(back) as VaultSuccess<bool>).data,
        isFalse,
      );
      final backKey = _keyOf(await repository.unlock(_master, back));
      expect(_openedOf(await open(sealed, backKey)).version, 1);
      await backKey.close();
      backKey.dispose();
    });
  });

  group('a vault with its own password', () {
    test(
        'init → unlock → seal/open item → rewrap → old password rejected → '
        'close → locked', () async {
      final metadata = _metadataOf(
        await repository.initializeVault(_password, ownPassword: true),
      );
      final wrapped = base64Decode(metadata.verificationToken);
      expect(wrapped.length, 103, reason: '0x10 blob: 6 + 16 + 9 + 24 + 48');
      expect(wrapped.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x10]);

      final key = _keyOf(await repository.unlock(_password, metadata));
      final sealed = await seal(key);
      expect(sealed.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x20]);

      // A password change re-wraps the key: the blob changes, the item does not.
      final rewrapped = _metadataOf(
        await repository.rewrap(_password, _newPassword, metadata),
      );
      expect(rewrapped.verificationToken, isNot(metadata.verificationToken));
      expect(rewrapped.vaultId, metadata.vaultId);
      expect(
        _failureOf(await repository.unlock(_password, rewrapped)),
        VaultFailureType.incorrectMasterPassword,
      );
      final newKey = _keyOf(await repository.unlock(_newPassword, rewrapped));
      expect(
        (_openedOf(await open(sealed, newKey)).content as VaultPasswordContent)
            .password,
        'hunter2',
      );

      // A closed handle seals and opens nothing.
      await key.close();
      expect(
        _failureOf(
          await repository.encryptContent(
            _content,
            key,
            itemId: _itemId,
            version: 1,
          ),
        ),
        VaultFailureType.unknown,
      );
      expect(
        _failureOf(await open(sealed, key)),
        VaultFailureType.decryptionFailed,
      );
      key.dispose();
      await newKey.close();
      newKey.dispose();
    });

    test('custom-password item round trip; wrong custom password rejected',
        () async {
      final metadata = _metadataOf(
        await repository.initializeVault(_password, ownPassword: true),
      );
      final key = _keyOf(await repository.unlock(_password, metadata));

      final sealed = await seal(key, custom: _customPassword);
      expect(
        sealed.sublist(0, 6),
        [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x05],
        reason: 'the 0x05 password layer wraps the sealed item',
      );
      expect(
        (_openedOf(await open(sealed, key, custom: _customPassword)).content
                as VaultPasswordContent)
            .password,
        'hunter2',
      );
      expect(
        _failureOf(await open(sealed, key, custom: 'not-it')),
        VaultFailureType.incorrectCustomPassword,
      );
      expect(
        _failureOf(await open(sealed, key)),
        VaultFailureType.decryptionFailed,
        reason: 'the 0x05 layer is not a vault item',
      );

      await key.close();
      key.dispose();
    });

    test('wrong password → incorrectMasterPassword; weak → weakPassword',
        () async {
      expect(
        _failureOf(await repository.initializeVault('abc', ownPassword: true)),
        VaultFailureType.weakPassword,
      );

      final metadata = _metadataOf(
        await repository.initializeVault(_password, ownPassword: true),
      );
      expect(
        _failureOf(await repository.unlock('wrong', metadata)),
        VaultFailureType.incorrectMasterPassword,
      );
      expect(
        _failureOf(await repository.rewrap('wrong', _newPassword, metadata)),
        VaultFailureType.incorrectMasterPassword,
      );
      expect(
        _failureOf(await repository.rewrap(_password, 'abc', metadata)),
        VaultFailureType.weakPassword,
      );

      final tampered = base64Decode(metadata.verificationToken);
      tampered[tampered.length - 1] ^= 0x01;
      expect(
        _failureOf(
          await repository.unlock(
            _password,
            metadata.copyWith(verificationToken: base64Encode(tampered)),
          ),
        ),
        VaultFailureType.incorrectMasterPassword,
      );
      expect(
        _failureOf(
          await repository.unlock(
            _password,
            metadata.copyWith(verificationToken: 'not base64'),
          ),
        ),
        VaultFailureType.fileCorrupted,
      );
    });

    test('a tampered item is decryptionFailed', () async {
      final metadata = _metadataOf(
        await repository.initializeVault(_password, ownPassword: true),
      );
      final key = _keyOf(await repository.unlock(_password, metadata));

      final sealed = await seal(key);
      sealed[sealed.length - 1] ^= 0x01;
      expect(
        _failureOf(await open(sealed, key)),
        VaultFailureType.decryptionFailed,
      );

      await key.close();
      key.dispose();
    });
  });

  group('the recovery key and a vault with its own password', () {
    Future<void> keepRecoveryKey() async {
      expect(
        await chatAuthRepository.saveRecovery(
          PendingRecoveryKey(
            recoveryKey: masterSetup.recoveryKey,
            recoveryWrap: masterSetup.recoveryWrap,
            recoveryLock: masterSetup.recoveryLock,
          ),
        ),
        isA<CryptoCoreSuccess<void>>(),
      );
    }

    Future<Uint8List?> storedCopy() async {
      final blobs = await chatAuthRepository.keyBlobs();
      return (blobs as CryptoCoreSuccess<MasterKeyBlobs>).data.vaultRecovery;
    }

    test(
        'made with its own password: the recovery key opens it with a new '
        'password; the master password does not', () async {
      await keepRecoveryKey();
      expect(await repository.hasRecoveryKey(), isTrue);
      final metadata = _metadataOf(
        await repository.initializeVault(_password, ownPassword: true),
      );
      final copy = await storedCopy();
      expect(copy, isNotNull);
      expect(copy!.length, 110, reason: '0x11: 6 + 32 + 24 + 48');
      expect(copy.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x11]);
      expect(await repository.hasRecoveryCopy(), isTrue);

      final key = _keyOf(await repository.unlock(_password, metadata));
      final sealed = await seal(key);
      await key.close();
      key.dispose();
      expect(
        _failureOf(await repository.unlock(_master, metadata)),
        VaultFailureType.incorrectMasterPassword,
      );

      expect(
        _failureOf(
          await repository.recover(
            recoveryKey: 'AAAA-AAAA',
            newPassword: _newPassword,
            metadata: metadata,
          ),
        ),
        VaultFailureType.recoveryKeyTypo,
      );
      expect(
        _failureOf(
          await repository.recover(
            recoveryKey: masterSetup.recoveryKey,
            newPassword: 'short',
            metadata: metadata,
          ),
        ),
        VaultFailureType.weakPassword,
      );
      final recovered = (await repository.recover(
        recoveryKey: masterSetup.recoveryKey.toLowerCase(),
        newPassword: _newPassword,
        metadata: metadata,
      ) as VaultSuccess<({VaultKey key, VaultMetadata metadata})>)
          .data;
      expect(_openedOf(await open(sealed, recovered.key)).version, 1);
      await recovered.key.close();
      recovered.key.dispose();
      expect(
        _failureOf(await repository.unlock(_password, recovered.metadata)),
        VaultFailureType.incorrectMasterPassword,
      );
      final byNew = _keyOf(
        await repository.unlock(_newPassword, recovered.metadata),
      );
      expect(_openedOf(await open(sealed, byNew)).version, 1);
      await byNew.close();
      byNew.dispose();
      expect(await storedCopy(), copy, reason: 'the vault key did not change');
    });

    test(
        'switched to its own password, then back to the master password by '
        'the recovery key; the copy is dropped after', () async {
      await keepRecoveryKey();
      final underMaster =
          _metadataOf(await repository.initializeVault(_master));
      expect(await storedCopy(), isNull);
      final own = _metadataOf(
        await repository.useOwnPassword(
          masterPassword: _master,
          newPassword: _password,
          metadata: underMaster,
        ),
      );
      expect(await storedCopy(), isNotNull);

      final recovered = (await repository.recover(
        recoveryKey: masterSetup.recoveryKey,
        metadata: own,
      ) as VaultSuccess<({VaultKey key, VaultMetadata metadata})>)
          .data;
      await recovered.key.close();
      recovered.key.dispose();
      expect(
        (repository.usesOwnPassword(recovered.metadata) as VaultSuccess<bool>)
            .data,
        isFalse,
      );
      final byMaster =
          _keyOf(await repository.unlock(_master, recovered.metadata));
      await byMaster.close();
      byMaster.dispose();
      expect(await repository.dropRecoveryCopy(), isA<VaultSuccess<void>>());
      expect(await storedCopy(), isNull);
      expect(await repository.hasRecoveryCopy(), isFalse);
    });

    test('without a recovery key no copy is made and nothing recovers',
        () async {
      expect(await repository.hasRecoveryKey(), isFalse);
      final metadata = _metadataOf(
        await repository.initializeVault(_password, ownPassword: true),
      );
      expect(await storedCopy(), isNull);
      expect(
        _failureOf(
          await repository.recover(
            recoveryKey: masterSetup.recoveryKey,
            newPassword: _newPassword,
            metadata: metadata,
          ),
        ),
        VaultFailureType.noRecoveryKey,
      );
    });

    test(
        'a new recovery key needs the vault password, opens the vault, and '
        'ends the old key; a wrong vault password changes nothing', () async {
      await keepRecoveryKey();
      final metadata = _metadataOf(
        await repository.initializeVault(_password, ownPassword: true),
      );
      final oldCopy = await storedCopy();

      Future<CryptoCoreResponse<Uint8List>> Function(Uint8List) sealWith(
        String vaultPassword,
      ) =>
          (lock) => repository.sealForRecovery(
                vaultPassword: vaultPassword,
                metadata: metadata,
                recoveryLock: lock,
              );

      final wrongRes = await chatAuthRepository.newRecoveryKey(
        _master,
        sealVault: sealWith('not the vault password'),
      );
      expect(
        (wrongRes as CryptoCoreFailure).type,
        CryptoCoreFailureType.wrongPassword,
      );
      expect(await storedCopy(), oldCopy, reason: 'the old key still works');
      expect(await repository.hasRecoveryKey(), isTrue);

      final pending = (await chatAuthRepository.newRecoveryKey(
        _master,
        sealVault: sealWith(_password),
      ) as CryptoCoreSuccess<PendingRecoveryKey>)
          .data;
      expect(pending.vaultRecovery, isNotNull);
      expect(await repository.hasRecoveryKey(), isFalse, reason: 'old is out');
      expect(await storedCopy(), isNull);
      await chatAuthRepository.saveRecovery(pending);

      expect(
        _failureOf(
          await repository.recover(
            recoveryKey: masterSetup.recoveryKey,
            newPassword: _newPassword,
            metadata: metadata,
          ),
        ),
        VaultFailureType.recoveryKeyWrong,
      );
      final recovered = (await repository.recover(
        recoveryKey: pending.recoveryKey,
        newPassword: _newPassword,
        metadata: metadata,
      ) as VaultSuccess<({VaultKey key, VaultMetadata metadata})>)
          .data;
      await recovered.key.close();
      recovered.key.dispose();
    });
  });
}
