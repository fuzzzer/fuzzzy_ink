import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

import '../../../../helpers/crypto_core_test_init.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _password = 'Correct-Horse-Battery-9!';
const _newPassword = 'Staple-Orange-Kettle-7?';
const _customPassword = 'item-only';

VaultFailureType _failureOf(VaultResponse<dynamic> res) =>
    (res as VaultFailure).type;

VaultMetadata _metadataOf(VaultResponse<VaultMetadata> res) =>
    (res as VaultSuccess<VaultMetadata>).data;

VaultKey _keyOf(VaultResponse<VaultKey> res) =>
    (res as VaultSuccess<VaultKey>).data;

Uint8List _bytesOf(VaultResponse<Uint8List> res) =>
    (res as VaultSuccess<Uint8List>).data;

const _content = VaultPasswordContent(
  username: 'alice',
  password: 'hunter2',
  url: 'https://example.com',
  notes: 'a note',
);

void main() {
  setUpAll(initCryptoCoreForTests);

  late CryptoCoreService service;
  late VaultCryptoRepository repository;

  setUp(() {
    service = CryptoCoreService(storeDirectoryPath: '');
    repository = VaultCryptoRepository(
      passwordStrengthService: PasswordStrengthService(),
      cryptoCoreService: service,
    );
  });

  group('VaultCryptoRepository (real library)', () {
    test(
        'init → unlock → seal/open item → rewrap → old password rejected → '
        'close → locked', () async {
      final metadata = _metadataOf(await repository.initializeVault(_password));
      final wrapped = base64Decode(metadata.verificationToken);
      expect(wrapped.length, 103, reason: '0x10 blob: 6 + 16 + 9 + 24 + 48');
      expect(wrapped.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x10]);

      final key = _keyOf(await repository.unlock(_password, metadata));

      final sealed = _bytesOf(
        await repository.encryptContent(_content, key),
      );
      expect(sealed.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x20]);
      expect(
        utf8.decode(sealed, allowMalformed: true),
        isNot(contains('hunter2')),
      );

      final opened = await repository.decryptContent(
        sealed,
        key,
        VaultItemType.password,
      );
      expect(
        (opened as VaultSuccess<dynamic>).data,
        isA<VaultPasswordContent>()
            .having((c) => c.password, 'password', 'hunter2')
            .having((c) => c.username, 'username', 'alice'),
      );

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
      final reopened = await repository.decryptContent(
        sealed,
        newKey,
        VaultItemType.password,
      );
      expect(
        ((reopened as VaultSuccess<dynamic>).data as VaultPasswordContent)
            .password,
        'hunter2',
      );

      // A closed handle seals and opens nothing.
      await key.close();
      expect(
        _failureOf(await repository.encryptContent(_content, key)),
        VaultFailureType.unknown,
      );
      expect(
        _failureOf(
          await repository.decryptContent(sealed, key, VaultItemType.password),
        ),
        VaultFailureType.decryptionFailed,
      );
      key.dispose();
      await newKey.close();
      newKey.dispose();
    });

    test('custom-password item round trip; wrong custom password rejected',
        () async {
      final metadata = _metadataOf(await repository.initializeVault(_password));
      final key = _keyOf(await repository.unlock(_password, metadata));

      final sealed = _bytesOf(
        await repository.encryptContent(
          _content,
          key,
          customPassword: _customPassword,
        ),
      );
      expect(
        sealed.sublist(0, 6),
        [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x05],
        reason: 'the 0x05 password layer wraps the sealed item',
      );

      final opened = await repository.decryptContent(
        sealed,
        key,
        VaultItemType.password,
        customPassword: _customPassword,
      );
      expect(
        ((opened as VaultSuccess<dynamic>).data as VaultPasswordContent)
            .password,
        'hunter2',
      );

      expect(
        _failureOf(
          await repository.decryptContent(
            sealed,
            key,
            VaultItemType.password,
            customPassword: 'not-it',
          ),
        ),
        VaultFailureType.incorrectCustomPassword,
      );
      expect(
        _failureOf(
          await repository.decryptContent(sealed, key, VaultItemType.password),
        ),
        VaultFailureType.decryptionFailed,
        reason: 'the 0x05 layer is not a vault item',
      );

      await key.close();
      key.dispose();
    });

    test('wrong master password → incorrectMasterPassword; weak → weakPassword',
        () async {
      expect(
        _failureOf(await repository.initializeVault('abc')),
        VaultFailureType.weakPassword,
      );

      final metadata = _metadataOf(await repository.initializeVault(_password));
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
        VaultFailureType.unknown,
      );
    });

    test('a tampered item is decryptionFailed', () async {
      final metadata = _metadataOf(await repository.initializeVault(_password));
      final key = _keyOf(await repository.unlock(_password, metadata));

      final sealed = _bytesOf(await repository.encryptContent(_content, key));
      sealed[sealed.length - 1] ^= 0x01;
      expect(
        _failureOf(
          await repository.decryptContent(sealed, key, VaultItemType.password),
        ),
        VaultFailureType.decryptionFailed,
      );

      await key.close();
      key.dispose();
    });
  });
}
