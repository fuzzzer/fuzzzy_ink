import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

import '../../../helpers/crypto_core_test_init.dart';

T _dataOf<T>(CryptoCoreResponse<T> res) => (res as CryptoCoreSuccess<T>).data;

CryptoCoreFailureType _failureOf(CryptoCoreResponse<dynamic> res) =>
    (res as CryptoCoreFailure).type;

/// The first run's recovery key as the user confirms saving it.
PendingRecoveryKey _pendingOf(CryptoCoreMasterKeySetup setup) =>
    PendingRecoveryKey(
      recoveryKey: setup.recoveryKey,
      recoveryWrap: setup.recoveryWrap,
      recoveryLock: setup.recoveryLock,
    );

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

/// A hand-built 0x01 envelope naming [chatId]; only `peekChatId` reads it.
String _invitationNaming(String chatId) {
  final blob = [
    0x46, 0x55, 0x5A, 0x5A, 0x01, 0x01, // FUZZ · v1 · invitation
    chatId.length,
    ...utf8.encode(chatId),
    ...List.filled(32 * 3 + 64, 0x11),
  ];
  return 'Fuzz/${base64Url.encode(blob).replaceAll('=', '')}';
}

void main() {
  setUpAll(initCryptoCoreForTests);

  late Directory storeDir;
  late CryptoCoreService service;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storeDir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_');
    service = CryptoCoreService(storeDirectoryPath: storeDir.path);
  });

  tearDown(() async {
    await service.close();
    if (storeDir.existsSync()) storeDir.deleteSync(recursive: true);
  });

  group('CryptoCoreService master key (real library)', () {
    test(
        'createMasterKey opens the store → close → the password reopens it → '
        'a wrong one is refused and keeps an open store open', () async {
      final setup = _dataOf(await service.createMasterKey('first'));
      expect(setup.passwordWrap.length, 103, reason: '0x10: 6+16+9+24+48');
      expect(setup.recoveryWrap.length, 103);
      expect(setup.storeWrap.length, 78, reason: '0x20: 6+24+32+16');
      expect(setup.recoveryLock.length, 78, reason: '0x20 under the store key');
      expect(
        setup.recoveryKey,
        matches(RegExp(r'^([A-Z2-7]{4}-){7}[A-Z2-7]{4}$')),
      );
      expect(service.isOpen, isTrue);
      expect(
        Directory('${storeDir.path}/fuzzy_crypto_store').existsSync(),
        isTrue,
      );

      await service.close();
      expect(service.isOpen, isFalse);
      expect(
        await service.openStore(
          passwordWrap: setup.passwordWrap,
          storeWrap: setup.storeWrap,
          password: 'first',
        ),
        isA<CryptoCoreSuccess<void>>(),
      );
      expect(service.isOpen, isTrue);

      expect(
        _failureOf(
          await service.openStore(
            passwordWrap: setup.passwordWrap,
            storeWrap: setup.storeWrap,
            password: 'wrong',
          ),
        ),
        CryptoCoreFailureType.wrongPassword,
      );
      expect(
        service.isOpen,
        isTrue,
        reason: 'a wrong password keeps the store open',
      );

      await service.close();
      await service.close();
      expect(service.isOpen, isFalse, reason: 'close is idempotent');
    });

    test('the empty password is gone: no master key is made under it',
        () async {
      expect(
        _failureOf(await service.createMasterKey('')),
        CryptoCoreFailureType.wrongPassword,
      );
      expect(service.isOpen, isFalse);
    });

    test('concurrent createMasterKey calls queue and all succeed', () async {
      final results = await Future.wait([
        service.createMasterKey('a'),
        service.createMasterKey('b'),
        service.createMasterKey('c'),
      ]);
      expect(
        results,
        everyElement(isA<CryptoCoreSuccess<CryptoCoreMasterKeySetup>>()),
      );
      final wraps = results.map((res) => _dataOf(res).passwordWrap).toList();
      expect(wraps.map(base64Encode).toSet().length, 3);
    });

    test('app settings are sealed under the store key', () async {
      expect(
        _failureOf(
          await service.sealSetting(name: 'auto-lock', bytes: Uint8List(1)),
        ),
        CryptoCoreFailureType.storeLocked,
      );
      _dataOf(await service.createMasterKey('pw'));
      final sealed = _dataOf(
        await service.sealSetting(
          name: 'auto-lock',
          bytes: Uint8List.fromList(utf8.encode('{}')),
        ),
      );
      expect(
        utf8.decode(
          _dataOf(await service.openSetting(name: 'auto-lock', blob: sealed)),
        ),
        '{}',
      );
      sealed[sealed.length - 1] ^= 1;
      expect(
        _failureOf(await service.openSetting(name: 'auto-lock', blob: sealed)),
        CryptoCoreFailureType.corrupt,
      );
    });
  });

  group('ChatAuthRepository: the master password (real library)', () {
    late ChatAuthRepository chatAuthRepository;

    setUp(() {
      chatAuthRepository = ChatAuthRepository(
        localDataSource: MasterKeyLocalDataSource(),
        cryptoCoreService: service,
      );
    });

    test('notSetUp → setUp → ready → unlock → change → old rejected', () async {
      expect(
        _dataOf(await chatAuthRepository.status()),
        MasterKeyStatus.notSetUp,
      );
      expect(_dataOf(await chatAuthRepository.hasLegacyData()), isFalse);

      final setup = _dataOf(await chatAuthRepository.setUp('first'));
      expect(service.isOpen, isTrue);
      expect(_dataOf(await chatAuthRepository.status()), MasterKeyStatus.ready);
      expect(
        _dataOf(await chatAuthRepository.hasRecoveryKey()),
        isFalse,
        reason: 'kept only once the user confirms saving it',
      );
      _dataOf(await chatAuthRepository.saveRecovery(_pendingOf(setup)));
      expect(_dataOf(await chatAuthRepository.hasRecoveryKey()), isTrue);

      await service.close();
      expect(
        _failureOf(await chatAuthRepository.unlock('wrong')),
        CryptoCoreFailureType.wrongPassword,
      );
      expect(service.isOpen, isFalse);
      _dataOf(await chatAuthRepository.unlock('first'));
      expect(service.isOpen, isTrue);

      expect(
        _failureOf(
          await chatAuthRepository.changePassword(
            oldPassword: 'wrong',
            newPassword: 'second',
          ),
        ),
        CryptoCoreFailureType.wrongPassword,
      );
      _dataOf(
        await chatAuthRepository.changePassword(
          oldPassword: 'first',
          newPassword: 'second',
        ),
      );
      expect(
        _failureOf(await chatAuthRepository.unlock('first')),
        CryptoCoreFailureType.wrongPassword,
      );
      _dataOf(await chatAuthRepository.unlock('second'));
    });

    test(
        'a first run in two halves: nothing is kept until the key step ends, '
        'then the shown recovery key opens it', () async {
      final setup = _dataOf(await chatAuthRepository.prepareSetUp('first'));
      expect(service.isOpen, isTrue);
      expect(
        _dataOf(await chatAuthRepository.status()),
        MasterKeyStatus.notSetUp,
        reason: 'closed here, the next start is a first run again',
      );

      _dataOf(
        await chatAuthRepository.completeSetUp(setup, keepRecovery: true),
      );
      expect(_dataOf(await chatAuthRepository.status()), MasterKeyStatus.ready);
      expect(_dataOf(await chatAuthRepository.hasRecoveryKey()), isTrue);

      await service.close();
      _dataOf(
        await chatAuthRepository.recover(
          recoveryKey: setup.recoveryKey,
          newPassword: 'second',
        ),
      );
      expect(service.isOpen, isTrue);
    });

    test('a typed recovery key is checked for form before any key work',
        () async {
      final setup = _dataOf(await chatAuthRepository.prepareSetUp('first'));
      _dataOf(await chatAuthRepository.checkRecoveryKey(setup.recoveryKey));
      _dataOf(
        await chatAuthRepository.checkRecoveryKey(
          setup.recoveryKey.toLowerCase().replaceAll('-', ' '),
        ),
      );
      expect(
        _failureOf(await chatAuthRepository.checkRecoveryKey('AAAA-AAAA')),
        CryptoCoreFailureType.corrupt,
      );
    });

    test('a skipped recovery key is never kept', () async {
      final setup = _dataOf(await chatAuthRepository.prepareSetUp('first'));
      _dataOf(
        await chatAuthRepository.completeSetUp(setup, keepRecovery: false),
      );
      expect(_dataOf(await chatAuthRepository.status()), MasterKeyStatus.ready);
      expect(_dataOf(await chatAuthRepository.hasRecoveryKey()), isFalse);
    });

    test(
        'the recovery key sets a new password and keeps every chat; a typo '
        'is corrupt; a new key ends the old one', () async {
      const chatId = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
      final setup = _dataOf(await chatAuthRepository.setUp('first'));
      _dataOf(await chatAuthRepository.saveRecovery(_pendingOf(setup)));
      _dataOf(await service.createInvitation(chatId));
      final row = Uint8List.fromList([1, ...utf8.encode('Fuzz/row')]);
      final sealed = _dataOf(
        await service.sealLocal(
          chatId: chatId,
          row: row,
          bytes: Uint8List.fromList(utf8.encode('kept')),
        ),
      );
      await service.close();

      expect(
        _failureOf(
          await chatAuthRepository.recover(
            recoveryKey: 'AAAA-AAAA',
            newPassword: 'fresh',
          ),
        ),
        CryptoCoreFailureType.corrupt,
      );
      _dataOf(
        await chatAuthRepository.recover(
          recoveryKey: setup.recoveryKey.toLowerCase(),
          newPassword: 'fresh',
        ),
      );
      expect(service.isOpen, isTrue);
      expect(
        utf8.decode(
          _dataOf(
            await service.openLocal(chatId: chatId, row: row, blob: sealed),
          ),
        ),
        'kept',
      );
      expect(
        _failureOf(await chatAuthRepository.unlock('first')),
        CryptoCoreFailureType.wrongPassword,
      );
      _dataOf(await chatAuthRepository.unlock('fresh'));

      // A new recovery key: the old one is gone at once, the new one counts
      // once saved.
      final fresh = _dataOf(await chatAuthRepository.newRecoveryKey('fresh'));
      expect(_dataOf(await chatAuthRepository.hasRecoveryKey()), isFalse);
      _dataOf(await chatAuthRepository.saveRecovery(fresh));
      expect(
        _failureOf(
          await chatAuthRepository.recover(
            recoveryKey: setup.recoveryKey,
            newPassword: 'third',
          ),
        ),
        CryptoCoreFailureType.wrongPassword,
      );
      _dataOf(
        await chatAuthRepository.recover(
          recoveryKey: fresh.recoveryKey,
          newPassword: 'third',
        ),
      );
    });

    test('without a saved recovery key nothing recovers', () async {
      final setup = _dataOf(await chatAuthRepository.setUp('first'));
      expect(
        _failureOf(
          await chatAuthRepository.recover(
            recoveryKey: setup.recoveryKey,
            newPassword: 'fresh',
          ),
        ),
        CryptoCoreFailureType.wrongPassword,
      );
    });

    test('an install from before the master password is recognised', () async {
      FlutterSecureStorage.setMockInitialValues({
        MasterKeyLocalDataSource.legacyStoreKeyKey: 'old',
      });
      expect(_dataOf(await chatAuthRepository.hasLegacyData()), isTrue);
      expect(
        _dataOf(await chatAuthRepository.status()),
        MasterKeyStatus.notSetUp,
      );
    });

    test('unlock before the first run is internal and opens nothing', () async {
      expect(
        _failureOf(await chatAuthRepository.unlock('any')),
        CryptoCoreFailureType.internal,
      );
      expect(service.isOpen, isFalse);
    });
  });

  group('pairing through the service (real library, two stores)', () {
    late Directory bDir;
    late CryptoCoreService b;

    setUp(() async {
      bDir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_b_');
      b = CryptoCoreService(storeDirectoryPath: bDir.path);
      _dataOf(await service.createMasterKey('a'));
      _dataOf(await b.createMasterKey('b'));
    });

    tearDown(() async {
      await b.close();
      if (bDir.existsSync()) bDir.deleteSync(recursive: true);
    });

    test(
        'A invites → B accepts → A completes; re-display; second acceptance '
        'is invitationAlreadyUsed', () async {
      final invitationRes = await service.createInvitation(_chatId);
      final invitation =
          (invitationRes as CryptoCoreSuccess<CryptoCoreInvitation>).data;
      expect(invitation.chatId, _chatId);
      expect(invitation.content, startsWith('Fuzz/'));

      final peeked = service.peekChatId(invitation.content);
      expect((peeked as CryptoCoreSuccess<String>).data, _chatId);

      final acceptanceRes = await b.acceptInvitation(
        chatId: _chatId,
        invitation: invitation.content,
      );
      final acceptance =
          (acceptanceRes as CryptoCoreSuccess<CryptoCoreAcceptance>).data;
      expect(acceptance.chatId, _chatId);
      expect(
        (b.peekChatId(acceptance.content) as CryptoCoreSuccess<String>).data,
        _chatId,
      );

      expect(
        await service.completeHandshake(
          chatId: _chatId,
          acceptance: acceptance.content,
        ),
        isA<CryptoCoreSuccess<void>>(),
      );

      final current = await service.currentInvitation(_chatId);
      expect(
        (current as CryptoCoreSuccess<CryptoCoreInvitation>).data.content,
        invitation.content,
      );
      final currentAcc = await b.currentAcceptance(_chatId);
      expect(
        (currentAcc as CryptoCoreSuccess<CryptoCoreAcceptance>).data.content,
        acceptance.content,
      );

      expect(
        _failureOf(
          await service.completeHandshake(
            chatId: _chatId,
            acceptance: acceptance.content,
          ),
        ),
        CryptoCoreFailureType.invitationAlreadyUsed,
      );

      // B accepting again is `internal` on the core; the cubit pre-empts it.
      expect(
        _failureOf(
          await b.acceptInvitation(
            chatId: _chatId,
            invitation: invitation.content,
          ),
        ),
        CryptoCoreFailureType.internal,
      );
      expect(await b.deleteChat(_chatId), isA<CryptoCoreSuccess<void>>());
      expect(
        await b.acceptInvitation(
          chatId: _chatId,
          invitation: invitation.content,
        ),
        isA<CryptoCoreSuccess<CryptoCoreAcceptance>>(),
      );
    });

    test('tampered, foreign and garbage blobs map to the failure types',
        () async {
      final invitation = ((await service.createInvitation(_chatId))
              as CryptoCoreSuccess<CryptoCoreInvitation>)
          .data
          .content;

      final tampered = invitation.replaceRange(
        invitation.length - 5,
        invitation.length - 4,
        invitation[invitation.length - 5] == 'A' ? 'B' : 'A',
      );
      expect(
        _failureOf(
          await b.acceptInvitation(chatId: _chatId, invitation: tampered),
        ),
        CryptoCoreFailureType.invalidSignature,
      );

      const other = '00000000-0000-4000-8000-000000000000';
      expect(
        _failureOf(
          await b.acceptInvitation(chatId: other, invitation: invitation),
        ),
        CryptoCoreFailureType.wrongChat,
      );

      expect(
        _failureOf(service.peekChatId('not a blob')),
        CryptoCoreFailureType.unsupportedFormat,
      );
      // `FUZZ`, version 2: made by a newer app, not damaged.
      expect(
        _failureOf(service.peekChatId('Fuzz/RlVaWgIBAA')),
        CryptoCoreFailureType.newerVersion,
      );
      expect(
        _failureOf(
          await b.acceptInvitation(
            chatId: _chatId,
            invitation: 'Fuzz/RlVaWgIBAA',
          ),
        ),
        CryptoCoreFailureType.newerVersion,
      );
      expect(
        _failureOf(
          await service.completeHandshake(
            chatId: _chatId,
            acceptance: 'not a blob',
          ),
        ),
        CryptoCoreFailureType.unsupportedFormat,
      );
      expect(
        _failureOf(
          await service.completeHandshake(
            chatId: _chatId,
            acceptance: invitation,
          ),
        ),
        CryptoCoreFailureType.unsupportedFormat,
        reason: 'an invitation pasted as an acceptance',
      );
      expect(
        await service.currentAcceptance(_chatId),
        isA<CryptoCoreFailure<CryptoCoreAcceptance>>(),
      );
      expect(
        _failureOf(await service.currentInvitation(other)),
        CryptoCoreFailureType.unknownChat,
      );
    });

    test('peekChatId refuses a chat id that is not uuid-v4 shaped', () {
      expect(
        (service.peekChatId(_invitationNaming(_chatId))
                as CryptoCoreSuccess<String>)
            .data,
        _chatId,
      );
      for (final bad in ['x', '../../etc', _chatId.toUpperCase()]) {
        expect(
          _failureOf(service.peekChatId(_invitationNaming(bad))),
          CryptoCoreFailureType.corrupt,
          reason: bad,
        );
      }
    });

    test('safety number is identical on both sides; markVerified round-trips',
        () async {
      final invitation = ((await service.createInvitation(_chatId))
              as CryptoCoreSuccess<CryptoCoreInvitation>)
          .data;
      // A has no peer yet: no number, no flag to set.
      expect(
        _failureOf(await service.safetyNumber(_chatId)),
        CryptoCoreFailureType.unknownChat,
      );
      expect(
        (await service.isVerified(_chatId) as CryptoCoreSuccess<bool>).data,
        isFalse,
      );

      final acceptance = ((await b.acceptInvitation(
        chatId: _chatId,
        invitation: invitation.content,
      )) as CryptoCoreSuccess<CryptoCoreAcceptance>)
          .data;
      await service.completeHandshake(
        chatId: _chatId,
        acceptance: acceptance.content,
      );

      final numberA = (await service.safetyNumber(_chatId)
              as CryptoCoreSuccess<SafetyNumber>)
          .data;
      final numberB =
          (await b.safetyNumber(_chatId) as CryptoCoreSuccess<SafetyNumber>)
              .data;
      expect(numberA, numberB);
      expect(numberA.version, 1);
      expect(numberA.digits, matches(RegExp(r'^\d{5}( \d{5}){11}$')));

      expect(
        await service.markVerified(chatId: _chatId, verified: true),
        isA<CryptoCoreSuccess<void>>(),
      );
      expect(
        (await service.isVerified(_chatId) as CryptoCoreSuccess<bool>).data,
        isTrue,
      );
      // The flag is per device: B never marked.
      expect(
        (await b.isVerified(_chatId) as CryptoCoreSuccess<bool>).data,
        isFalse,
      );

      await service.close();
      expect(
        _failureOf(await service.isVerified(_chatId)),
        CryptoCoreFailureType.storeLocked,
      );
      expect(
        _failureOf(
          await service.markVerified(chatId: _chatId, verified: false),
        ),
        CryptoCoreFailureType.storeLocked,
      );
    });

    test('a closed store answers storeLocked; deleteChat is idempotent',
        () async {
      expect(await service.deleteChat(_chatId), isA<CryptoCoreSuccess<void>>());
      await service.close();
      expect(
        _failureOf(await service.createInvitation(_chatId)),
        CryptoCoreFailureType.storeLocked,
      );
      expect(
        _failureOf(await service.deleteChat(_chatId)),
        CryptoCoreFailureType.storeLocked,
      );
      expect(
        _failureOf(
          await service.completeHandshake(chatId: _chatId, acceptance: 'x'),
        ),
        CryptoCoreFailureType.storeLocked,
      );
    });
  });
}
