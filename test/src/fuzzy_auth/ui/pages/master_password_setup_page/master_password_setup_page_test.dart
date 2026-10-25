import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

class MockSetupCubit extends MockCubit<MasterPasswordSetupState>
    implements MasterPasswordSetupCubit {}

/// The first run's recovery-key step: the key is shown as text that cannot
/// be selected, and the app goes on only after "I saved it" or an explicit
/// skip past the warning.
void main() {
  late MockSetupCubit cubit;
  final l10n = FuzzzyInkLocalizationsEn();
  const recoveryKey = 'AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQZ';

  setUp(() {
    cubit = MockSetupCubit();
    when(() => cubit.skipRecoveryKey()).thenReturn(null);
    when(() => cubit.confirmRecoveryKeySaved()).thenAnswer((_) async {});
    whenListen(
      cubit,
      const Stream<MasterPasswordSetupState>.empty(),
      initialState: MasterPasswordSetupState(
        step: MasterPasswordSetupStep.recoveryKey,
        status: StateStatus.success,
        recoveryKey: recoveryKey,
        recoveryWrap: Uint8List(1),
      ),
    );
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecoveryKeyPanel(
              recoveryKey: recoveryKey,
              busy: false,
              onConfirmed: cubit.confirmRecoveryKeySaved,
              onSkipped: cubit.skipRecoveryKey,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the key and the warning, and is not selectable text',
      (tester) async {
    await pumpPanel(tester);
    expect(find.text(recoveryKey.replaceAll('-', ' ')), findsOneWidget);
    expect(find.text(l10n.recoveryKeyWarning), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(SelectionArea), findsNothing);
  });

  testWidgets('Continue stays off until "I have saved my recovery key"',
      (tester) async {
    await pumpPanel(tester);
    FuzzzyButton continueButton() => tester.widget<FuzzzyButton>(
          find.widgetWithText(FuzzzyButton, l10n.recoveryKeyContinue),
        );
    expect(continueButton().onPressed, isNull);

    await tester.tap(find.text(l10n.recoveryKeyConfirm));
    await tester.pump();
    expect(continueButton().onPressed, isNotNull);
    await tester.tap(find.text(l10n.recoveryKeyContinue));
    verify(() => cubit.confirmRecoveryKeySaved()).called(1);
  });

  testWidgets('skipping asks first, with the explicit warning', (tester) async {
    await pumpPanel(tester);
    await tester.tap(find.text(l10n.recoveryKeySkip));
    await tester.pumpAndSettle();
    expect(find.text(l10n.recoveryKeySkipMessage), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    verifyNever(() => cubit.skipRecoveryKey());

    await tester.tap(find.text(l10n.recoveryKeySkip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recoveryKeySkipConfirm));
    await tester.pumpAndSettle();
    verify(() => cubit.skipRecoveryKey()).called(1);
  });
}
