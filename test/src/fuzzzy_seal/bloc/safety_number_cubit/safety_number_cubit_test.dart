import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _safetyNumber =
    '12345 67890 11111 22222 33333 44444 55555 66666 77777 88888 99999 00000';

void main() {
  late MockCryptoCoreService mockService;

  setUp(() {
    mockService = MockCryptoCoreService();
    when(() => mockService.safetyNumber(_chatId))
        .thenAnswer((_) async => const CryptoCoreSuccess(_safetyNumber));
    when(() => mockService.isVerified(_chatId))
        .thenAnswer((_) async => const CryptoCoreSuccess(false));
    when(
      () => mockService.markVerified(
        chatId: any(named: 'chatId'),
        verified: any(named: 'verified'),
      ),
    ).thenAnswer((_) async => const CryptoCoreSuccess(null));
  });

  SafetyNumberCubit build() => SafetyNumberCubit(
        chatId: _chatId,
        cryptoCoreService: mockService,
      );

  Matcher loaded({required bool isVerified}) => isA<SafetyNumberState>()
      .having((s) => s.status, 'status', StateStatus.success)
      .having((s) => s.safetyNumber, 'safetyNumber', _safetyNumber)
      .having((s) => s.isVerified, 'isVerified', isVerified);

  final failed = isA<SafetyNumberState>()
      .having((s) => s.status, 'status', StateStatus.failed)
      .having((s) => s.failure, 'failure', isNotNull);

  // -----------------------------------------------------------------------
  // load
  // -----------------------------------------------------------------------
  group('load', () {
    blocTest<SafetyNumberCubit, SafetyNumberState>(
      'reads the number and the flag from the core',
      setUp: () {
        when(() => mockService.isVerified(_chatId))
            .thenAnswer((_) async => const CryptoCoreSuccess(true));
      },
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SafetyNumberState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        loaded(isVerified: true),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockService.safetyNumber(_chatId),
          () => mockService.isVerified(_chatId),
        ]);
      },
    );

    blocTest<SafetyNumberCubit, SafetyNumberState>(
      'a chat without a peer yet fails without asking for the flag',
      setUp: () {
        when(() => mockService.safetyNumber(_chatId)).thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.unknownChat),
        );
      },
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SafetyNumberState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        failed,
      ],
      verify: (_) {
        verifyNever(() => mockService.isVerified(any()));
      },
    );

    blocTest<SafetyNumberCubit, SafetyNumberState>(
      'a locked store on the flag read fails',
      setUp: () {
        when(() => mockService.isVerified(_chatId)).thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.storeLocked),
        );
      },
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SafetyNumberState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        failed,
      ],
    );
  });

  // -----------------------------------------------------------------------
  // toggleVerified
  // -----------------------------------------------------------------------
  group('toggleVerified', () {
    blocTest<SafetyNumberCubit, SafetyNumberState>(
      'marks through the core, then unmarks',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.toggleVerified();
        await cubit.toggleVerified();
      },
      skip: 2,
      expect: () => [
        loaded(isVerified: true),
        loaded(isVerified: false),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockService.markVerified(chatId: _chatId, verified: true),
          () => mockService.markVerified(chatId: _chatId, verified: false),
        ]);
      },
    );

    blocTest<SafetyNumberCubit, SafetyNumberState>(
      'a core failure leaves the flag as it was',
      setUp: () {
        when(
          () => mockService.markVerified(
            chatId: any(named: 'chatId'),
            verified: any(named: 'verified'),
          ),
        ).thenAnswer(
          (_) async => const CryptoCoreFailure(CryptoCoreFailureType.io),
        );
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.toggleVerified();
      },
      skip: 2,
      expect: () => [
        failed.having((s) => s.isVerified, 'isVerified', false),
      ],
    );
  });
}
