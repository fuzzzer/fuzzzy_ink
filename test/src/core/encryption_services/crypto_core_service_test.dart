import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/crypto_core_test_init.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockUserAuthPreferencesRepository extends Mock
    implements UserAuthPreferencesRepository {}

Uint8List? _blobOf(CryptoCoreResponse<Uint8List?> readRes) =>
    (readRes as CryptoCoreSuccess<Uint8List?>).data;

CryptoCoreFailureType _failureOf(CryptoCoreResponse<dynamic> res) =>
    (res as CryptoCoreFailure).type;

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
  late CryptoStoreKeyRepository storeKeyRepository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storeDir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_');
    service = CryptoCoreService(storeDirectoryPath: storeDir.path);
    storeKeyRepository = CryptoStoreKeyRepository(cryptoCoreService: service);
  });

  tearDown(() async {
    await service.close();
    if (storeDir.existsSync()) storeDir.deleteSync(recursive: true);
  });

  group('CryptoCoreService + CryptoStoreKeyRepository (real library)', () {
    test(
        'ensureStoreKey → openStore → rewrap → open with new password → '
        'old password rejected → close', () async {
      expect(
        await storeKeyRepository.ensureStoreKey('a'),
        isA<CryptoCoreSuccess<void>>(),
      );
      final wrapped = _blobOf(await storeKeyRepository.read());
      expect(wrapped, isNotNull);
      expect(wrapped!.length, 103, reason: '0x10 blob: 6 + 16 + 9 + 24 + 48');

      // A second call is a no-op: the same blob stays in place.
      expect(
        await storeKeyRepository.ensureStoreKey('other'),
        isA<CryptoCoreSuccess<void>>(),
      );
      expect(_blobOf(await storeKeyRepository.read()), wrapped);

      expect(
        await service.openStore(wrapped: wrapped, password: 'a'),
        isA<CryptoCoreSuccess<void>>(),
      );
      expect(service.isOpen, isTrue);
      expect(
        Directory('${storeDir.path}/fuzzy_crypto_store').existsSync(),
        isTrue,
      );

      expect(
        await storeKeyRepository.rewrap(oldPassword: 'a', newPassword: 'b'),
        isA<CryptoCoreSuccess<void>>(),
      );
      final rewrapped = _blobOf(await storeKeyRepository.read());
      expect(rewrapped, isNot(wrapped));

      expect(
        await service.openStore(wrapped: rewrapped!, password: 'b'),
        isA<CryptoCoreSuccess<void>>(),
      );
      expect(service.isOpen, isTrue);

      final wrongRes =
          await service.openStore(wrapped: rewrapped, password: 'a');
      expect(wrongRes, isA<CryptoCoreFailure<void>>());
      expect(
        (wrongRes as CryptoCoreFailure<void>).type,
        CryptoCoreFailureType.wrongPassword,
      );
      expect(
        service.isOpen,
        isTrue,
        reason: 'a wrong password keeps the store open',
      );

      await service.close();
      expect(service.isOpen, isFalse);
      await service.close();
      expect(service.isOpen, isFalse, reason: 'close is idempotent');
    });

    test('rewrap with the wrong old password changes nothing', () async {
      await storeKeyRepository.ensureStoreKey('a');
      final wrapped = _blobOf(await storeKeyRepository.read());

      final rewrapRes =
          await storeKeyRepository.rewrap(oldPassword: 'x', newPassword: 'b');
      expect(rewrapRes, isA<CryptoCoreFailure<void>>());
      expect(
        (rewrapRes as CryptoCoreFailure<void>).type,
        CryptoCoreFailureType.wrongPassword,
      );
      expect(_blobOf(await storeKeyRepository.read()), wrapped);
    });

    test('rewrap without a store key is internal', () async {
      final rewrapRes =
          await storeKeyRepository.rewrap(oldPassword: '', newPassword: 'b');
      expect(rewrapRes, isA<CryptoCoreFailure<void>>());
      expect(
        (rewrapRes as CryptoCoreFailure<void>).type,
        CryptoCoreFailureType.internal,
      );
    });

    test('concurrent createStoreKey calls queue and all succeed', () async {
      final results = await Future.wait([
        service.createStoreKey('a'),
        service.createStoreKey('b'),
        service.createStoreKey('c'),
      ]);
      expect(results, everyElement(isA<CryptoCoreSuccess<Uint8List>>()));
      final blobs = results
          .map((res) => (res as CryptoCoreSuccess<Uint8List>).data)
          .toList();
      expect(blobs.toSet().length, 3);
    });
  });

  group('ChatAuthRepository change-password round trip (real library)', () {
    late MockUserAuthPreferencesRepository userAuthPreferencesRepository;
    late ChatAuthRepository chatAuthRepository;

    setUp(() {
      userAuthPreferencesRepository = MockUserAuthPreferencesRepository();
      when(() => userAuthPreferencesRepository.updateUserAuthPreferences(any()))
          .thenAnswer((_) async {});
      chatAuthRepository = ChatAuthRepository(
        userAuthPreferencesRepository: userAuthPreferencesRepository,
        cryptoStoreKeyRepository: storeKeyRepository,
        cryptoCoreService: service,
      );
    });

    setUpAll(() {
      registerFallbackValue(
        UserAuthPreferences(isAuthenticationOnceEnabled: false),
      );
    });

    test('setup → verify → change → verify new → old rejected → disable',
        () async {
      // Lock disabled: the key is wrapped under '' and the store opens with it.
      await storeKeyRepository.ensureStoreKey('');
      expect(await chatAuthRepository.verifyPassword(''), isTrue);

      expect(await chatAuthRepository.setupPassword('first'), isTrue);
      expect(await chatAuthRepository.verifyPassword('wrong'), isFalse);
      expect(service.isOpen, isTrue);
      expect(await chatAuthRepository.verifyPassword('first'), isTrue);

      expect(
        await chatAuthRepository.changePassword(
          oldPassword: 'wrong',
          newPassword: 'second',
        ),
        isFalse,
      );

      expect(
        await chatAuthRepository.changePassword(
          oldPassword: 'first',
          newPassword: 'second',
        ),
        isTrue,
      );

      expect(await chatAuthRepository.verifyPassword('second'), isTrue);
      expect(await chatAuthRepository.verifyPassword('first'), isFalse);

      expect(await chatAuthRepository.disableAuth('second'), isTrue);
      expect(await chatAuthRepository.verifyPassword(''), isTrue);
      expect(await chatAuthRepository.verifyPassword('second'), isFalse);
    });

    test('verifyPassword without a store key is false', () async {
      expect(await chatAuthRepository.verifyPassword('any'), isFalse);
      expect(service.isOpen, isFalse);
    });

    test('isChatAuthEnabled without a store key is false', () async {
      when(() => userAuthPreferencesRepository.getUserAuthPreferences())
          .thenAnswer(
        (_) async => UserAuthPreferences(isAuthenticationOnceEnabled: true),
      );

      expect(await chatAuthRepository.isChatAuthEnabled(), isFalse);
      expect(service.isOpen, isFalse);
      verifyNever(
        () => userAuthPreferencesRepository.updateUserAuthPreferences(any()),
      );
    });

    // A kill between the two writes of enable / disable leaves the blob
    // rewrapped and the preference stale (F2-6 review R1). Each half of
    // `setupPassword` / `disableAuth` is replayed by hand: the rewrap lands,
    // the preference write never does.
    test('kill between the enable writes: blob wins, preference repaired',
        () async {
      await storeKeyRepository.ensureStoreKey('');
      when(() => userAuthPreferencesRepository.getUserAuthPreferences())
          .thenAnswer((_) async => null);

      await storeKeyRepository.rewrap(oldPassword: '', newPassword: 'pw');

      expect(await chatAuthRepository.isChatAuthEnabled(), isTrue);
      expect(service.isOpen, isFalse, reason: "'' no longer opens the store");
      final repaired = verify(
        () => userAuthPreferencesRepository.updateUserAuthPreferences(
          captureAny(),
        ),
      ).captured.single as UserAuthPreferences;
      expect(repaired.isAuthenticationOnceEnabled, isTrue);

      expect(await chatAuthRepository.verifyPassword('pw'), isTrue);
    });

    test('kill between the disable writes: blob wins, preference repaired',
        () async {
      await storeKeyRepository.ensureStoreKey('');
      expect(await chatAuthRepository.setupPassword('pw'), isTrue);
      when(() => userAuthPreferencesRepository.getUserAuthPreferences())
          .thenAnswer(
        (_) async => UserAuthPreferences(isAuthenticationOnceEnabled: true),
      );

      await storeKeyRepository.rewrap(oldPassword: 'pw', newPassword: '');

      expect(await chatAuthRepository.isChatAuthEnabled(), isFalse);
      expect(service.isOpen, isTrue, reason: "'' opens the store again");
      final repaired = verify(
        () => userAuthPreferencesRepository.updateUserAuthPreferences(
          captureAny(),
        ),
      ).captured.last as UserAuthPreferences;
      expect(repaired.isAuthenticationOnceEnabled, isFalse);
    });

    test('consistent states leave the preference alone', () async {
      await storeKeyRepository.ensureStoreKey('');
      when(() => userAuthPreferencesRepository.getUserAuthPreferences())
          .thenAnswer((_) async => null);
      expect(await chatAuthRepository.isChatAuthEnabled(), isFalse);
      verifyNever(
        () => userAuthPreferencesRepository.updateUserAuthPreferences(any()),
      );

      expect(await chatAuthRepository.setupPassword('pw'), isTrue);
      when(() => userAuthPreferencesRepository.getUserAuthPreferences())
          .thenAnswer(
        (_) async => UserAuthPreferences(isAuthenticationOnceEnabled: true),
      );
      expect(await chatAuthRepository.isChatAuthEnabled(), isTrue);
      verify(
        () => userAuthPreferencesRepository.updateUserAuthPreferences(any()),
      ).called(1);
    });
  });

  group('pairing through the service (real library, two stores)', () {
    late Directory bDir;
    late CryptoCoreService b;

    Future<void> openWithoutPassword(
      CryptoCoreService service,
      CryptoStoreKeyRepository repository,
    ) async {
      await repository.ensureStoreKey('');
      await service.openStore(
        wrapped: _blobOf(await repository.read())!,
        password: '',
      );
    }

    setUp(() async {
      bDir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_b_');
      b = CryptoCoreService(storeDirectoryPath: bDir.path);
      await openWithoutPassword(service, storeKeyRepository);
      // B's blob replaces A's in the mock secure storage; A is already open.
      await openWithoutPassword(
        b,
        CryptoStoreKeyRepository(cryptoCoreService: b),
      );
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

      final numberA =
          (await service.safetyNumber(_chatId) as CryptoCoreSuccess<String>)
              .data;
      final numberB =
          (await b.safetyNumber(_chatId) as CryptoCoreSuccess<String>).data;
      expect(numberA, numberB);
      expect(numberA, matches(RegExp(r'^\d{5}( \d{5}){11}$')));

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
