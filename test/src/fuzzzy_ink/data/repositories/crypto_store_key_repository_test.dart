import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

/// The real `flutter_secure_storage` method channel, answered by a handler
/// that throws the macOS keychain error for the methods listed in `failing`
/// (T-0327: `-34018`, missing entitlement) and serves `stored` otherwise.
const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

PlatformException _keychainError() => PlatformException(
      code: 'Unexpected security result code',
      message: "A required entitlement isn't present.",
      details: -34018,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late MockCryptoCoreService mockService;
  late CryptoStoreKeyRepository repository;
  late Map<String, String> stored;
  late Set<String> failing;

  final blob = Uint8List.fromList(List.filled(103, 0x10));
  final newBlob = Uint8List.fromList(List.filled(103, 0x11));

  setUp(() {
    mockService = MockCryptoCoreService();
    repository = CryptoStoreKeyRepository(cryptoCoreService: mockService);
    stored = {};
    failing = {};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (failing.contains(call.method)) throw _keychainError();
      final args = call.arguments as Map<dynamic, dynamic>;
      switch (call.method) {
        case 'read':
          return stored[args['key'] as String];
        case 'write':
          stored[args['key'] as String] = args['value'] as String;
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  CryptoCoreFailureType typeOf(CryptoCoreResponse<dynamic> res) =>
      (res as CryptoCoreFailure).type;

  group('secure storage throws (macOS -34018)', () {
    test('read returns io instead of throwing', () async {
      failing = {'read'};

      final readRes = await repository.read();

      expect(readRes, isA<CryptoCoreFailure<Uint8List?>>());
      expect(typeOf(readRes), CryptoCoreFailureType.io);
    });

    test('ensureStoreKey returns io when the read throws, service untouched',
        () async {
      failing = {'read'};

      final res = await repository.ensureStoreKey('');

      expect(typeOf(res), CryptoCoreFailureType.io);
      verifyNever(() => mockService.createStoreKey(any()));
    });

    test('ensureStoreKey returns io when the write throws', () async {
      failing = {'write'};
      when(() => mockService.createStoreKey(''))
          .thenAnswer((_) async => CryptoCoreSuccess(blob));

      final res = await repository.ensureStoreKey('');

      expect(typeOf(res), CryptoCoreFailureType.io);
      expect(stored, isEmpty);
    });

    test('rewrap returns io when the read throws, service untouched', () async {
      failing = {'read'};

      final res = await repository.rewrap(oldPassword: '', newPassword: 'pw');

      expect(typeOf(res), CryptoCoreFailureType.io);
      verifyNever(
        () => mockService.rewrapStoreKey(
          wrapped: any(named: 'wrapped'),
          oldPassword: any(named: 'oldPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      );
    });

    test('rewrap returns io when the write throws, old blob untouched',
        () async {
      stored['crypto_store_key_v1'] = base64Encode(blob);
      failing = {'write'};
      when(
        () => mockService.rewrapStoreKey(
          wrapped: blob,
          oldPassword: '',
          newPassword: 'pw',
        ),
      ).thenAnswer((_) async => CryptoCoreSuccess(newBlob));

      final res = await repository.rewrap(oldPassword: '', newPassword: 'pw');

      expect(typeOf(res), CryptoCoreFailureType.io);
      expect(stored['crypto_store_key_v1'], base64Encode(blob));
    });
  });

  group('secure storage works', () {
    test('ensureStoreKey creates once and rewrap replaces the blob', () async {
      when(() => mockService.createStoreKey(''))
          .thenAnswer((_) async => CryptoCoreSuccess(blob));
      when(
        () => mockService.rewrapStoreKey(
          wrapped: blob,
          oldPassword: '',
          newPassword: 'pw',
        ),
      ).thenAnswer((_) async => CryptoCoreSuccess(newBlob));

      expect(
        await repository.ensureStoreKey(''),
        isA<CryptoCoreSuccess<void>>(),
      );
      expect(
        await repository.ensureStoreKey('other'),
        isA<CryptoCoreSuccess<void>>(),
      );
      verify(() => mockService.createStoreKey('')).called(1);
      expect(stored['crypto_store_key_v1'], base64Encode(blob));

      expect(
        await repository.rewrap(oldPassword: '', newPassword: 'pw'),
        isA<CryptoCoreSuccess<void>>(),
      );
      expect(stored['crypto_store_key_v1'], base64Encode(newBlob));
    });
  });
}
