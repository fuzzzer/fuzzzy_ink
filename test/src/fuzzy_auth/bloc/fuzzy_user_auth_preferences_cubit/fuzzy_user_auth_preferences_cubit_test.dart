import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

class MockChatAuthRepository extends Mock implements ChatAuthRepository {}

class MockFuzzyAuthStore extends Mock implements FuzzyAuthStore {}

class MockBiometricAuthRepository extends Mock
    implements BiometricAuthRepository {}

/// A new or changed app-lock password must reach the vault's "good" bar
/// (security review 2026-10-22, item 6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const weak = 'a';
  const fair = 'abcdefgh';
  const good = 'Blue-Kettle-42';

  late MockChatAuthRepository chatAuthRepository;
  late MockFuzzyAuthStore store;
  late MockBiometricAuthRepository biometricRepository;

  setUp(() {
    chatAuthRepository = MockChatAuthRepository();
    store = MockFuzzyAuthStore();
    biometricRepository = MockBiometricAuthRepository();
    when(() => chatAuthRepository.verifyPassword(any()))
        .thenAnswer((_) async => true);
    when(() => store.setBiometricEnabled(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
    when(() => chatAuthRepository.setupPassword(any()))
        .thenAnswer((_) async => true);
    when(() => store.onPasswordSetup(any())).thenAnswer((_) async {});
    when(
      () => store.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async => true);
  });

  FuzzyUserAuthPreferencesCubit buildCubit() => FuzzyUserAuthPreferencesCubit(
        chatAuthRepository: chatAuthRepository,
        fuzzyAuthStore: store,
        biometricAuthRepository: biometricRepository,
        passwordStrengthService: PasswordStrengthService(),
      );

  test('"good" and "strong" pass; "weak" and "fair" do not', () {
    final cubit = buildCubit();
    expect(cubit.isStrongEnough(''), isFalse);
    expect(cubit.isStrongEnough(weak), isFalse);
    expect(cubit.isStrongEnough(fair), isFalse);
    expect(cubit.isStrongEnough('password123'), isFalse);
    expect(cubit.isStrongEnough(good), isTrue);
    cubit.close();
  });

  for (final password in [weak, fair]) {
    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'turning the lock on with "$password" fails and changes nothing',
      build: buildCubit,
      act: (cubit) => cubit.enableAuth(password),
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.failed)
            .having(
              (s) => s.activationFailure?.message,
              'message',
              FuzzzyInkLocalizationsEn().chatAuthPasswordTooWeak,
            ),
      ],
      verify: (_) {
        verifyNever(() => chatAuthRepository.setupPassword(any()));
        verifyNever(() => store.onPasswordSetup(any()));
      },
    );
  }

  blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
    'turning the lock on with a good password goes ahead',
    build: buildCubit,
    act: (cubit) => cubit.enableAuth(good),
    expect: () => [
      isA<FuzzyUserAuthPreferencesState>()
          .having((s) => s.activationStatus, 'status', StateStatus.loading),
      isA<FuzzyUserAuthPreferencesState>()
          .having((s) => s.activationStatus, 'status', StateStatus.success),
    ],
    verify: (_) {
      verify(() => chatAuthRepository.setupPassword(good)).called(1);
    },
  );

  blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
    'changing to a weak password fails before the old one is even checked',
    build: buildCubit,
    act: (cubit) => cubit.changePassword(oldPassword: 'x', newPassword: weak),
    expect: () => [
      isA<FuzzyUserAuthPreferencesState>()
          .having((s) => s.activationStatus, 'status', StateStatus.failed)
          .having(
            (s) => s.lastAction,
            'lastAction',
            AuthPreferencesAction.changePassword,
          ),
    ],
    verify: (_) {
      verifyNever(
        () => store.changePassword(
          oldPassword: any(named: 'oldPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      );
    },
  );

  blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
    'changing from a weak old password to a good one goes ahead',
    build: buildCubit,
    act: (cubit) => cubit.changePassword(oldPassword: weak, newPassword: good),
    expect: () => [
      isA<FuzzyUserAuthPreferencesState>()
          .having((s) => s.activationStatus, 'status', StateStatus.loading),
      isA<FuzzyUserAuthPreferencesState>()
          .having((s) => s.activationStatus, 'status', StateStatus.success),
    ],
    verify: (_) {
      verify(
        () => store.changePassword(oldPassword: weak, newPassword: good),
      ).called(1);
    },
  );

  setUpAll(() => registerFallbackValue(BiometricScope.chat));

  for (final (result, message) in [
    (
      BiometricEnableResult.notStrongEnough,
      FuzzzyInkLocalizationsEn().biometricNotStrongEnough,
    ),
    (
      BiometricEnableResult.cancelled,
      FuzzzyInkLocalizationsEn().biometricNotTurnedOn,
    ),
    (
      BiometricEnableResult.failed,
      FuzzzyInkLocalizationsEn().biometricNotTurnedOn,
    ),
  ]) {
    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'turning biometrics on that ends "${result.name}" shows a plain message '
      'and leaves them off',
      setUp: () {
        when(() => biometricRepository.enable(BiometricScope.chat, good))
            .thenAnswer((_) async => result);
      },
      build: buildCubit,
      act: (cubit) => cubit.enableBiometric(good),
      skip: 1,
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.failed)
            .having((s) => s.activationFailure?.message, 'message', message),
      ],
      verify: (_) {
        verifyNever(
          () => store.setBiometricEnabled(enabled: any(named: 'enabled')),
        );
      },
    );
  }
}
