import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class MockVaultAuthCubit extends MockCubit<VaultAuthState>
    implements VaultAuthCubit {}

/// A vault whose move to its private folder is unfinished is never offered
/// to be created again (that would leave the real one behind).
void main() {
  testWidgets('an unfinished move shows why and how to retry, not "create"',
      (tester) async {
    final cubit = MockVaultAuthCubit();
    whenListen(
      cubit,
      const Stream<VaultAuthState>.empty(),
      initialState: const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.moveUnfinished,
      ),
    );

    await tester.pumpWidget(
      BlocProvider<VaultAuthCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          home: const Scaffold(body: VaultEntryPage()),
        ),
      ),
    );
    await tester.pump();

    final en = FuzzzyInkLocalizationsEn();
    expect(find.text(en.vaultMoveUnfinishedTitle), findsOneWidget);
    expect(find.text(en.vaultMoveUnfinishedMessage), findsOneWidget);
    expect(find.byType(VaultCreatePage), findsNothing);
  });
}
