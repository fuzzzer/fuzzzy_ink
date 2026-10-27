import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:go_router/go_router.dart';

/// After a lock, unlocking goes back where the app was (QA 2026-10-26: it
/// always went to Home) — but never to a private screen: the screens on top
/// that show a secret are dropped as the app locks, so nothing they held is
/// kept while it is locked.
void main() {
  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    Widget page(String name) => Scaffold(body: Text(name));
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (_, __, child) => child,
          routes: [
            GoRoute(path: AppRouter.home, builder: (_, __) => page('home')),
            GoRoute(
              path: AppRouter.settings,
              builder: (_, __) => page('settings'),
            ),
          ],
        ),
        GoRoute(path: AppRouter.person, builder: (_, __) => page('person')),
        GoRoute(
          path: AppRouter.personItem,
          builder: (_, state) => page('item ${state.extra}'),
        ),
        GoRoute(
          path: AppRouter.settingsHowItWorks,
          builder: (_, __) => page('how it works'),
        ),
        GoRoute(
          path: AppRouter.chatUnlock,
          builder: (_, __) => page('locked'),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(AppRouter.forgetReturnPlace);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    return router;
  }

  testWidgets('a plain screen comes back, with the screens under it',
      (tester) async {
    final router = await pumpRouter(tester);
    router.go(AppRouter.settings);
    unawaited(router.push(AppRouter.settingsHowItWorks));
    await tester.pumpAndSettle();

    AppRouter.rememberReturnPlace(router);
    router.go(AppRouter.chatUnlock);
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);

    AppRouter.returnAfterUnlock(router);
    await tester.pumpAndSettle();
    expect(find.text('how it works'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets(
      'a private screen is not kept: its parent comes back, and the '
      'secret it was given is gone', (tester) async {
    final router = await pumpRouter(tester);
    unawaited(router.push('${AppRouter.person}?chat=c1'));
    unawaited(router.push(AppRouter.personItem, extra: 'opened text'));
    await tester.pumpAndSettle();
    expect(find.text('item opened text'), findsOneWidget);

    AppRouter.rememberReturnPlace(router);
    final kept = AppRouter.debugReturnPlace!;
    expect(
      kept.matches.map((match) => match.matchedLocation),
      isNot(contains(AppRouter.personItem)),
    );
    router.go(AppRouter.chatUnlock);
    await tester.pumpAndSettle();

    AppRouter.returnAfterUnlock(router);
    await tester.pumpAndSettle();
    expect(find.text('person'), findsOneWidget);
    expect(find.text('item opened text'), findsNothing);
  });

  testWidgets('nothing remembered: Home', (tester) async {
    final router = await pumpRouter(tester);
    router.go(AppRouter.chatUnlock);
    await tester.pumpAndSettle();
    AppRouter.rememberReturnPlace(router);
    expect(AppRouter.debugReturnPlace, isNull);
    AppRouter.returnAfterUnlock(router);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
