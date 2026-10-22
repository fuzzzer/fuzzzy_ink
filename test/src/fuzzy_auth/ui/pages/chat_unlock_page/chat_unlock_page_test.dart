import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

class MockFuzzyAuthStore extends MockCubit<FuzzyAuthState>
    implements FuzzyAuthStore {}

/// The unlock page during a wait after wrong passwords, and after an update
/// turned biometric unlock off (security review 2026-10-22, items 2 and 6).
void main() {
  late MockFuzzyAuthStore store;

  setUp(() => store = MockFuzzyAuthStore());

  Future<void> pumpPage(
    WidgetTester tester,
    FuzzyAuthState state, {
    Stream<FuzzyAuthState> changes = const Stream.empty(),
  }) async {
    whenListen(store, changes, initialState: state);
    await tester.pumpWidget(
      BlocProvider<FuzzyAuthStore>.value(
        value: store,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          home: const ChatUnlockPage(),
        ),
      ),
    );
    await tester.pump();
  }

  final locked =
      const FuzzyAuthState.initial().copyWith(status: AuthStateStatus.locked);

  testWidgets('a running wait shows the time left and keeps Unlock off',
      (tester) async {
    await pumpPage(
      tester,
      locked.copyWith(lockoutRemaining: const Duration(minutes: 1, seconds: 5)),
    );
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.pump();

    expect(
      find.text(FuzzzyInkLocalizationsEn().chatAuthLockedOut('1:05')),
      findsOneWidget,
    );
    final button = tester.widget<FuzzzyButton>(find.byType(FuzzzyButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('without a wait Unlock works once a password is typed',
      (tester) async {
    await pumpPage(tester, locked);
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.pump();

    expect(find.textContaining('1:05'), findsNothing);
    final button = tester.widget<FuzzzyButton>(find.byType(FuzzzyButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Enter on the keyboard tries nothing while a check runs',
      (tester) async {
    await pumpPage(
      tester,
      locked.copyWith(status: AuthStateStatus.unlocking),
    );
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verifyNever(() => store.unlock(any()));
  });

  testWidgets('Enter on the keyboard tries the password when idle',
      (tester) async {
    when(() => store.unlock(any())).thenAnswer((_) async {});
    await pumpPage(tester, locked);
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(() => store.unlock('pw')).called(1);
  });

  testWidgets('the one-time notice stays once an update turned biometrics off',
      (tester) async {
    await pumpPage(
      tester,
      const FuzzyAuthState.initial(),
      changes: Stream.value(locked.copyWith(biometricReset: true)),
    );
    await tester.pump();

    expect(
      find.text(FuzzzyInkLocalizationsEn().chatAuthBiometricReset),
      findsOneWidget,
    );
  });
}
