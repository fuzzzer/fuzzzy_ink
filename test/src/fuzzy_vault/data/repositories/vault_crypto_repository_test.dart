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

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storeDir = Directory.systemTemp.createTempSync('vault_crypto_repo_');
    service = CryptoCoreService(storeDirectoryPath: storeDir.path);
    final chatAuthRepository = ChatAuthRepository(
      localDataSource: MasterKeyLocalDataSource(),
      cryptoCoreService: service,
    );
    expect(
      await chatAuthRepository.setUp(_master),
      isA<CryptoCoreSuccess<CryptoCoreMasterKeySetup>>(),
    );
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
}
