import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFuzzyAuthStore extends MockCubit<FuzzyAuthState>
    implements FuzzyAuthStore {}

class MockVaultAuthCubit extends MockCubit<VaultAuthState>
    implements VaultAuthCubit {}

class MockVaultRepository extends Mock implements VaultRepository {}

/// The My safe tab: every state is one private screen that stays across the
/// change from locked to open, and an unfinished move is never offered to
/// be created again (that would leave the real safe behind).
void main() {
  final en = FuzzzyInkLocalizationsEn();
  late MockVaultAuthCubit cubit;
  late MockVaultRepository repository;

  setUp(() async {
    cubit = MockVaultAuthCubit();
    when(() => cubit.lockoutRemaining()).thenAnswer((_) async => Duration.zero);
    repository = MockVaultRepository();
    when(() => repository.vaultDataUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.getAllItems())
        .thenAnswer((_) async => const VaultSuccess([]));
    when(() => repository.getAllGroups())
        .thenAnswer((_) async => const VaultSuccess([]));
    SharedPreferences.setMockInitialValues({});
    sl
      ..safeRegisterSingleton<PreferencesService>(
        PreferencesService(await SharedPreferences.getInstance()),
      )
      ..registerFactory<VaultItemsCubit>(
        () => VaultItemsCubit(vaultRepository: repository),
      )
      ..registerFactory<VaultGroupsCubit>(
        () => VaultGroupsCubit(vaultRepository: repository),
      )
      ..registerFactory<VaultSearchCubit>(
        () => VaultSearchCubit(vaultRepository: repository),
      );
  });

  tearDown(() async {
    await sl.unregister<PreferencesService>();
    await sl.unregister<VaultItemsCubit>();
    await sl.unregister<VaultGroupsCubit>();
    await sl.unregister<VaultSearchCubit>();
  });

  Future<void> pump(
    WidgetTester tester,
    VaultAuthState state, {
    Stream<VaultAuthState> stream = const Stream.empty(),
  }) async {
    whenListen(cubit, stream, initialState: state);
    final authStore = MockFuzzyAuthStore();
    whenListen(
      authStore,
      const Stream<FuzzyAuthState>.empty(),
      initialState: const FuzzyAuthState.initial(),
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<VaultAuthCubit>.value(value: cubit),
          BlocProvider<FuzzyAuthStore>.value(value: authStore),
        ],
        child: MaterialApp(
          theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          home: const Scaffold(body: VaultEntryPage()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an unfinished move shows why and how to retry, nothing else',
      (tester) async {
    await pump(
      tester,
      const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.moveUnfinished,
      ),
    );

    expect(find.text(en.vaultMoveUnfinishedTitle), findsOneWidget);
    expect(find.text(en.vaultMoveUnfinishedMessage), findsOneWidget);
    expect(find.byType(VaultUnlockPage), findsNothing);
    expect(ScreenGuard.instance.isProtecting, isTrue);
  });

  testWidgets('locked, then open: one private screen the whole time',
      (tester) async {
    final states = StreamController<VaultAuthState>();
    addTearDown(states.close);
    await pump(
      tester,
      const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.locked,
      ),
      stream: states.stream,
    );
    expect(find.byType(VaultUnlockPage), findsOneWidget);
    final privateBefore = tester.state(find.byType(SensitiveScreen));

    states.add(
      const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.unlocked,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(VaultHomePage), findsOneWidget);
    expect(tester.state(find.byType(SensitiveScreen)), same(privateBefore));
    expect(ScreenGuard.instance.isProtecting, isTrue);
    // The open safe lifts in once (slow 420 ms), then settles.
    await tester.pumpAndSettle();
    expect(find.text(en.safeEmptyTitle), findsOneWidget);
  });
}
