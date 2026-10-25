import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

class MockVaultAuthCubit extends MockCubit<VaultAuthState>
    implements VaultAuthCubit {}

/// The recovery key also opens a vault with its own password (owner,
/// 2026-10-26): the locked vault offers it, and the form sets a new vault
/// password or hands the vault back to the master password.
void main() {
  final en = FuzzzyInkLocalizationsEn();
  late MockVaultAuthCubit cubit;

  setUp(() {
    sl.safeRegisterSingleton<PasswordStrengthService>(
      PasswordStrengthService(),
    );
    cubit = MockVaultAuthCubit();
    when(
      () => cubit.recover(
        recoveryKey: any(named: 'recoveryKey'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(() => sl.unregister<PasswordStrengthService>());

  Future<void> pump(WidgetTester tester, VaultAuthState state) async {
    whenListen(
      cubit,
      const Stream<VaultAuthState>.empty(),
      initialState: state,
    );
    await tester.pumpWidget(
      BlocProvider<VaultAuthCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [
                VaultOwnPasswordNote(),
                Expanded(child: VaultUnlockPage()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'a recoverable vault offers the recovery key, and the master password '
      'can take over', (tester) async {
    await pump(
      tester,
      const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.locked,
        usesOwnPassword: true,
        recoverable: true,
        recoveryKeyKept: true,
      ),
    );
    expect(find.text(en.vaultOwnPasswordRecoveryNote), findsOneWidget);
    expect(find.text(en.vaultForgotPassword), findsNothing);

    await tester.tap(find.text(en.vaultUseRecoveryKey));
    await tester.pump();
    expect(find.text(en.vaultRecoveryTitle), findsOneWidget);

    // The recovery key is the form's first field.
    await tester.enterText(
      find.byType(TextField).first,
      'aaaq-eaye-auda-ocaj-bifq-ydio-b4ib-ceqz',
    );
    await tester.tap(find.text(en.vaultRecoveryUseMasterPassword));
    await tester.pump();
    await tester.tap(find.text(en.vaultRecoverySubmit).last);
    await tester.pump();

    verify(
      () => cubit.recover(
        recoveryKey: 'aaaq-eaye-auda-ocaj-bifq-ydio-b4ib-ceqz',
      ),
    ).called(1);
  });

  testWidgets('without a recovery copy the vault password is the only way in',
      (tester) async {
    await pump(
      tester,
      const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.locked,
        usesOwnPassword: true,
      ),
    );
    expect(find.text(en.vaultForgotPassword), findsOneWidget);
    expect(find.text(en.vaultUseRecoveryKey), findsNothing);
    expect(find.text(en.vaultOwnPasswordNote), findsOneWidget);
  });
}
