import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

const _key = 'correct horse';
const _blob = '${fuzzIdentificator}RlVaWgEF';

void main() {
  late MockCryptoCoreService mockService;

  setUp(() {
    mockService = MockCryptoCoreService();
  });

  BasicEncryptionCubit build() =>
      BasicEncryptionCubit(cryptoCoreService: mockService);

  void stubSeal(CryptoCoreResponse<String> response) {
    when(
      () => mockService.passwordSealText(
        password: any(named: 'password'),
        text: any(named: 'text'),
      ),
    ).thenAnswer((_) async => response);
  }

  void stubOpen(CryptoCoreResponse<String> response) {
    when(
      () => mockService.passwordOpenText(
        password: any(named: 'password'),
        blob: any(named: 'blob'),
      ),
    ).thenAnswer((_) async => response);
  }

  Matcher loading() => isA<BasicEncryptionState>()
      .having((s) => s.status, 'status', StateStatus.loading);

  Matcher failed(String message) => isA<BasicEncryptionState>()
      .having((s) => s.status, 'status', StateStatus.failed)
      .having((s) => s.failure?.message, 'failure.message', message)
      .having((s) => s.result, 'result', isNull);

  group('encryptText', () {
    blocTest<BasicEncryptionCubit, BasicEncryptionState>(
      'seals the text under the key and emits the blob',
      setUp: () => stubSeal(const CryptoCoreSuccess(_blob)),
      build: build,
      act: (cubit) => cubit.encryptText(text: 'hello', key: _key),
      expect: () => [
        loading(),
        isA<BasicEncryptionState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.result, 'result', _blob),
      ],
      verify: (_) {
        verify(
          () => mockService.passwordSealText(password: _key, text: 'hello'),
        ).called(1);
      },
    );

    blocTest<BasicEncryptionCubit, BasicEncryptionState>(
      'an empty text or key fails before the service is called',
      build: build,
      act: (cubit) async {
        await cubit.encryptText(text: '', key: _key);
        await cubit.encryptText(text: 'hello', key: '');
      },
      expect: () => [
        failed('textAndKeyCannotBeEmpty'),
        failed('textAndKeyCannotBeEmpty'),
      ],
      verify: (_) => verifyZeroInteractions(mockService),
    );

    blocTest<BasicEncryptionCubit, BasicEncryptionState>(
      'a core failure is encryptionFailed',
      setUp: () => stubSeal(
        const CryptoCoreFailure(CryptoCoreFailureType.internal),
      ),
      build: build,
      act: (cubit) => cubit.encryptText(text: 'hello', key: _key),
      expect: () => [loading(), failed('encryptionFailed')],
    );
  });

  group('decryptText', () {
    blocTest<BasicEncryptionCubit, BasicEncryptionState>(
      'opens the blob under the key and emits the text',
      setUp: () => stubOpen(const CryptoCoreSuccess('hello')),
      build: build,
      act: (cubit) => cubit.decryptText(encryptedText: _blob, key: _key),
      expect: () => [
        loading(),
        isA<BasicEncryptionState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.result, 'result', 'hello'),
      ],
      verify: (_) {
        verify(
          () => mockService.passwordOpenText(password: _key, blob: _blob),
        ).called(1);
      },
    );

    blocTest<BasicEncryptionCubit, BasicEncryptionState>(
      'an empty blob or key fails before the service is called',
      build: build,
      act: (cubit) async {
        await cubit.decryptText(encryptedText: '', key: _key);
        await cubit.decryptText(encryptedText: _blob, key: '');
      },
      expect: () => [
        failed('encryptedTextAndKeyCannotBeEmpty'),
        failed('encryptedTextAndKeyCannotBeEmpty'),
      ],
      verify: (_) => verifyZeroInteractions(mockService),
    );

    for (final (type, message) in [
      (CryptoCoreFailureType.wrongPassword, 'basicsWrongPassword'),
      (CryptoCoreFailureType.corrupt, 'corruptBlob'),
      (CryptoCoreFailureType.unsupportedFormat, 'corruptBlob'),
      (
        CryptoCoreFailureType.internal,
        'decryptionFailedCheckYourKeyOrEncryptedText',
      ),
    ]) {
      blocTest<BasicEncryptionCubit, BasicEncryptionState>(
        '${type.name} reads as $message',
        setUp: () => stubOpen(CryptoCoreFailure(type)),
        build: build,
        act: (cubit) => cubit.decryptText(encryptedText: _blob, key: _key),
        expect: () => [loading(), failed(message)],
      );
    }

    blocTest<BasicEncryptionCubit, BasicEncryptionState>(
      'a failed decrypt clears the previous result',
      setUp: () => stubOpen(const CryptoCoreSuccess('hello')),
      build: build,
      seed: () => const BasicEncryptionState(
        status: StateStatus.success,
        result: 'hello',
      ),
      act: (cubit) async {
        stubOpen(const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword));
        await cubit.decryptText(encryptedText: _blob, key: 'wrong');
      },
      expect: () => [
        isA<BasicEncryptionState>()
            .having((s) => s.status, 'status', StateStatus.loading)
            .having((s) => s.result, 'result', 'hello'),
        failed('basicsWrongPassword'),
      ],
    );
  });
}
