import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVaultAuthCubit extends MockCubit<VaultAuthState>
    implements VaultAuthCubit {}

class _MockPeople extends MockCubit<ChatGeneralDataListState>
    implements ChatGeneralDataListCubit {}

class _MockAuthStore extends MockCubit<FuzzyAuthState>
    implements FuzzyAuthStore {}

void main() {
  late PreferencesService preferences;
  late _MockVaultAuthCubit vault;
  late _MockPeople people;
  late _MockAuthStore authStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = PreferencesService(await SharedPreferences.getInstance());
    vault = _MockVaultAuthCubit();
    when(() => vault.state).thenReturn(
      const VaultAuthState(authState: VaultAuthEnum.unlocked),
    );
    when(() => vault.lock()).thenAnswer((_) async {});
    people = _MockPeople();
    when(() => people.state).thenReturn(
      const ChatGeneralDataListState(status: StateStatus.success, chatList: []),
    );
    authStore = _MockAuthStore();
    when(() => authStore.lock(byUser: any(named: 'byUser')))
        .thenAnswer((_) async {});
  });

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);

    final rootKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootKey,
      routes: [
        ShellRoute(
          builder: (_, __, child) =>
              MainShellPage(preferencesService: preferences, child: child),
          routes: [
            GoRoute(
              path: AppRouter.home,
              builder: (_, __) => const Text('home tab'),
            ),
            GoRoute(
              path: AppRouter.vaultHome,
              builder: (_, __) => const Text('safe tab'),
            ),
            GoRoute(
              path: AppRouter.settings,
              builder: (_, __) => const Text('settings tab'),
            ),
          ],
        ),
        GoRoute(
          path: AppRouter.chatCreate,
          builder: (_, __) => const Text('full screen flow'),
        ),
        GoRoute(
          path: AppRouter.open,
          builder: (_, __) => const Text('open flow'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<VaultAuthCubit>.value(value: vault),
          BlocProvider<ChatGeneralDataListCubit>.value(value: people),
          BlocProvider<FuzzyAuthStore>.value(value: authStore),
        ],
        child: MaterialApp.router(
          theme: FuzzzyTheme.build(inkPack, skin),
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
            ),
            child: app!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  for (final skin in [FuzzzySkin.paper, FuzzzySkin.night]) {
    testWidgets('phone: three tabs at the bottom, each remembered ($skin)',
        (tester) async {
      await pumpShell(tester, skin: skin);
      expect(find.byType(FuzzzyBottomNav), findsOneWidget);
      expect(find.byType(FuzzzySideNav), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('MY SAFE'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('home tab'), findsOneWidget);

      await tester.tap(find.text('MY SAFE'));
      await tester.pumpAndSettle();
      expect(find.text('safe tab'), findsOneWidget);
      expect(preferences.lastSelectedTab, AppRouter.vaultHome);

      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();
      expect(find.text('settings tab'), findsOneWidget);
      expect(preferences.lastSelectedTab, AppRouter.settings);
    });
  }

  testWidgets('My safe has its own header with the lock while it is open',
      (tester) async {
    final router = await pumpShell(tester);
    router.go(AppRouter.vaultHome);
    await tester.pumpAndSettle();
    expect(find.text('My safe'), findsOneWidget);

    await tester.tap(find.byKey(const Key('iconbtn.mySafe.lock')));
    verify(() => vault.lock()).called(1);
  });

  testWidgets('wide screens get the side rail instead, with the mark',
      (tester) async {
    await pumpShell(tester, size: const Size(1024, 768));
    expect(find.byType(FuzzzySideNav), findsOneWidget);
    expect(find.byType(FuzzzyBottomNav), findsNothing);
    expect(find.byType(InkMark), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('settings tab'), findsOneWidget);
  });

  testWidgets('full-screen flows sit outside the tabs', (tester) async {
    final router = await pumpShell(tester);
    unawaited(router.push(AppRouter.chatCreate));
    await tester.pumpAndSettle();
    expect(find.text('full screen flow'), findsOneWidget);
    expect(find.byType(FuzzzyBottomNav), findsNothing);
  });

  testWidgets('the content lifts in once; not with reduced motion',
      (tester) async {
    await pumpShell(tester, reduceMotion: true);
    expect(find.byType(LiftIn), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('every location maps to its tab', () {
    expect(MainShellPage.indexOf('/'), 0);
    expect(MainShellPage.indexOf('/vault'), 1);
    expect(MainShellPage.indexOf('/vault/editor'), 1);
    expect(MainShellPage.indexOf('/settings'), 2);
  });

  group('computer keys (DESIGN.md section 6)', () {
    Future<void> press(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      bool shift = false,
    }) async {
      final modifier = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
    }

    testWidgets('⌘/Ctrl + O opens Open',
        variant: TargetPlatformVariant.desktop(), (tester) async {
      await pumpShell(tester, size: const Size(1024, 768));
      await press(tester, LogicalKeyboardKey.keyO);
      expect(find.text('open flow'), findsOneWidget);
    });

    testWidgets('⌘/Ctrl + , goes to Settings',
        variant: TargetPlatformVariant.desktop(), (tester) async {
      await pumpShell(tester, size: const Size(1024, 768));
      await press(tester, LogicalKeyboardKey.comma);
      expect(find.text('settings tab'), findsOneWidget);
      expect(preferences.lastSelectedTab, AppRouter.settings);
    });

    testWidgets('⌘/Ctrl + L asks who it is for, as the Lock tile does',
        variant: TargetPlatformVariant.desktop(), (tester) async {
      await pumpShell(tester, size: const Size(1024, 768));
      await press(tester, LogicalKeyboardKey.keyL);
      expect(find.byKey(const Key('sheet.lockWho')), findsOneWidget);
    });

    testWidgets('⌘/Ctrl + Shift + L locks the app',
        variant: TargetPlatformVariant.desktop(), (tester) async {
      await pumpShell(tester, size: const Size(1024, 768));
      await press(tester, LogicalKeyboardKey.keyL, shift: true);
      verify(() => authStore.lock(byUser: true)).called(1);
      expect(find.byKey(const Key('sheet.lockWho')), findsNothing);
    });

    testWidgets('a phone has none', variant: TargetPlatformVariant.mobile(),
        (tester) async {
      await pumpShell(tester);
      await press(tester, LogicalKeyboardKey.keyO);
      expect(find.text('open flow'), findsNothing);
    });
  });
}
