import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

final _nino = ChatGeneralData(
  chatId: '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d',
  chatName: 'Nino',
  setupStatus: ChatSetupStatus.connected,
  didAcceptInvitation: false,
);

void main() {
  Future<GoRouter> pumpRouted(
    WidgetTester tester, {
    required bool returnsToPerson,
    int? row,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('home')),
        GoRoute(
          path: AppRouter.chatConnected,
          builder: (_, state) => Text(
            'person '
            '${(state.extra! as ConnectedChatPagePayload).chatGeneralData.chatName}',
          ),
        ),
        GoRoute(
          path: AppRouter.lockFor,
          builder: (context, _) => TextButton(
            onPressed: () => landOnPerson(
              context,
              chat: _nino,
              returnsToPerson: returnsToPerson,
              historyRowId: row,
            ),
            child: const Text('done'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    return router;
  }

  tearDown(() => RecentHistoryRow.take(_nino.chatId));

  testWidgets(
      'from Home: Home comes back with the person on top, the row '
      'marked once', (tester) async {
    final router = await pumpRouted(tester, returnsToPerson: false, row: 7);
    unawaited(router.push(AppRouter.lockFor));
    await tester.pumpAndSettle();
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(find.text('person Nino'), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(RecentHistoryRow.take(_nino.chatId), 7);
    expect(RecentHistoryRow.take(_nino.chatId), isNull);
  });

  testWidgets('from the person page: the flow just closes', (tester) async {
    final router = await pumpRouted(tester, returnsToPerson: true);
    unawaited(
      router.push(
        AppRouter.chatConnected,
        extra: ConnectedChatPagePayload(chatGeneralData: _nino),
      ),
    );
    unawaited(router.push(AppRouter.lockFor));
    await tester.pumpAndSettle();
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(find.text('person Nino'), findsOneWidget);
    expect(RecentHistoryRow.peek(_nino.chatId), isNull);
  });
}
