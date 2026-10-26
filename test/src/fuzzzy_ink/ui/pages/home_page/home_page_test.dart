import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_cast/fuzzzy_cast.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockChatList extends MockCubit<ChatGeneralDataListState>
    implements ChatGeneralDataListCubit {}

ChatGeneralData _chat(String id, String name, ChatSetupStatus status) =>
    ChatGeneralData(
      chatId: id,
      chatName: name,
      setupStatus: status,
      didAcceptInvitation: false,
    );

final _mom = _chat('mom', 'Mom', ChatSetupStatus.invited);
final _nino = _chat('nino', 'Nino', ChatSetupStatus.connected);
final _tamar = _chat('tamar', 'Tamar', ChatSetupStatus.connected);

const _loaded = StateStatus.success;

void main() {
  late _MockChatList chatList;

  setUp(() {
    chatList = _MockChatList();
    FuzzzyCastThrottle.reset();
  });

  void showState(ChatGeneralDataListState state) =>
      when(() => chatList.state).thenReturn(state);

  Future<void> pumpHome(
    WidgetTester tester, {
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
    bool castOn = false,
  }) async {
    tester.view.physicalSize =
        const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({'fuzzzy_cast_enabled': castOn});
    final preferences =
        PreferencesService(await SharedPreferences.getInstance());

    Widget stub(String name) => Scaffold(body: Text(name));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: AppRouter.home,
          builder: (_, __) => const Scaffold(
            body: HomePage(),
          ),
        ),
        GoRoute(
          path: AppRouter.chatCreate,
          builder: (_, __) => stub('send invite flow'),
        ),
        GoRoute(
          path: AppRouter.chatAccept,
          builder: (_, __) => stub('got invite flow'),
        ),
        GoRoute(
          path: AppRouter.lockWithPassword,
          builder: (_, __) => stub('password flow'),
        ),
        GoRoute(
          path: AppRouter.lockFor,
          builder: (_, state) => stub(
            'lock for ${(state.extra! as LockPagePayload).chat!.chatName}',
          ),
        ),
        GoRoute(
          path: AppRouter.open,
          builder: (_, __) => stub('open flow'),
        ),
        GoRoute(
          path: AppRouter.chatInvitation,
          builder: (_, state) => stub(
            'invite of ${(state.extra! as ChatInvitationPagePayload).chatName}',
          ),
        ),
        GoRoute(
          path: AppRouter.chatConnected,
          builder: (_, state) => stub(
            'chat with ${(state.extra! as ConnectedChatPagePayload).chatGeneralData.chatName}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ChatGeneralDataListCubit>.value(value: chatList),
          BlocProvider(
            create: (_) =>
                FuzzzyCastSettingsCubit(preferencesService: preferences),
          ),
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
    await tester.pump();
  }

  group('states', () {
    for (final skin in [FuzzzySkin.paper, FuzzzySkin.night]) {
      testWidgets('loading: the tiles and three skeleton rows ($skin)',
          (tester) async {
        showState(const ChatGeneralDataListState(status: StateStatus.loading));
        await pumpHome(tester, skin: skin);
        expect(find.byKey(const Key('tile.home.lock')), findsOneWidget);
        expect(find.byKey(const Key('tile.home.open')), findsOneWidget);
        expect(find.byKey(const Key('home.loading')), findsOneWidget);
        expect(find.byType(FuzzzySkeleton), findsNWidgets(9));
        expect(find.byType(InkMark), findsOneWidget);
      });

      testWidgets('load error: one fact and what to do ($skin)',
          (tester) async {
        showState(const ChatGeneralDataListState(status: StateStatus.failed));
        await pumpHome(tester, skin: skin);
        expect(
          find.text("Couldn't load your people. Close and open the app again."),
          findsOneWidget,
        );
      });

      for (final reduced in [false, true]) {
        testWidgets(
            'empty: the picture, "No one yet", the steps and both doors '
            '($skin, reduced motion $reduced)', (tester) async {
          showState(
            const ChatGeneralDataListState(status: _loaded, chatList: []),
          );
          await pumpHome(tester, skin: skin, reduceMotion: reduced);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('home.empty')), findsOneWidget);
          expect(find.text('No one yet'), findsOneWidget);
          expect(
            find.byKey(const Key('steps_picture.home.empty')),
            findsOneWidget,
          );
          expect(find.text('You send an invite'), findsOneWidget);
          expect(find.byKey(const Key('hero.home.empty')), findsOneWidget);
          expect(find.byKey(const Key('btn.home.add')), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('empty with Fuzzzy Cast on: Fuzzz in the picture slot',
        (tester) async {
      showState(const ChatGeneralDataListState(status: _loaded, chatList: []));
      await pumpHome(tester, castOn: true);
      expect(find.byType(CastFigure), findsOneWidget);
      expect(find.byKey(const Key('hero.home.empty')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'empty: "Send an invite" and "I got an invite" open their '
        'flows', (tester) async {
      showState(const ChatGeneralDataListState(status: _loaded, chatList: []));
      await pumpHome(tester);
      await tester.tap(find.text('Send an invite'));
      await tester.pumpAndSettle();
      expect(find.text('send invite flow'), findsOneWidget);
    });

    testWidgets('people: count, a chip for each, the waiting line, and Add',
        (tester) async {
      showState(
        ChatGeneralDataListState(
          status: _loaded,
          chatList: [_mom, _nino, _tamar],
          unverifiedChatIds: const {'tamar'},
        ),
      );
      await pumpHome(tester);
      expect(find.text('PEOPLE · 3'), findsOneWidget);
      expect(find.byKey(const Key('person.mom')), findsOneWidget);
      expect(find.text('Then you can lock for each other'), findsOneWidget);
      expect(find.byKey(const ValueKey(PersonTrust.waiting)), findsOneWidget);
      expect(find.byKey(const ValueKey(PersonTrust.checked)), findsOneWidget);
      expect(
        find.byKey(const ValueKey(PersonTrust.notChecked)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home.addPerson')), findsOneWidget);
      expect(find.byKey(const Key('btn.home.add')), findsOneWidget);
    });

    testWidgets(
        'a waiting person opens their invite, a connected one their '
        'page', (tester) async {
      showState(
        ChatGeneralDataListState(status: _loaded, chatList: [_mom, _nino]),
      );
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('person.mom')));
      await tester.pumpAndSettle();
      expect(find.text('invite of Mom'), findsOneWidget);
    });

    testWidgets('a connected person opens their page', (tester) async {
      showState(
        ChatGeneralDataListState(status: _loaded, chatList: [_mom, _nino]),
      );
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('person.nino')));
      await tester.pumpAndSettle();
      expect(find.text('chat with Nino'), findsOneWidget);
    });
  });

  group('Lock', () {
    testWidgets(
        '"Who\'s it for?": connected people, waiting ones off, and '
        'locking with a password', (tester) async {
      showState(
        ChatGeneralDataListState(status: _loaded, chatList: [_mom, _nino]),
      );
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('tile.home.lock')));
      await tester.pumpAndSettle();

      expect(find.text("Who's it for?"), findsOneWidget);
      expect(find.byKey(const Key('lockWho.nino')), findsOneWidget);
      expect(find.byKey(const Key('lockWho.mom')), findsOneWidget);
      expect(find.text('Add a person first'), findsNothing);

      // A waiting person cannot be locked for yet.
      await tester.tap(find.byKey(const Key('lockWho.mom')));
      await tester.pumpAndSettle();
      expect(find.text("Who's it for?"), findsOneWidget);

      await tester.tap(find.text('Lock with a password'));
      await tester.pumpAndSettle();
      expect(find.text('password flow'), findsOneWidget);
    });

    testWidgets('a connected person goes on to "What?" for them',
        (tester) async {
      showState(ChatGeneralDataListState(status: _loaded, chatList: [_nino]));
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('tile.home.lock')));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2 · Who'.toUpperCase()), findsOneWidget);
      await tester.tap(find.byKey(const Key('lockWho.nino')));
      await tester.pumpAndSettle();
      expect(find.text('lock for Nino'), findsOneWidget);
    });

    testWidgets('no one connected: "Add a person first" opens Add',
        (tester) async {
      showState(ChatGeneralDataListState(status: _loaded, chatList: [_mom]));
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('tile.home.lock')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a person first'));
      await tester.pumpAndSettle();
      expect(find.text('Add a person'), findsWidgets);
      expect(find.text('You start'), findsOneWidget);
      expect(find.text('They started'), findsOneWidget);
    });
  });

  group('Add', () {
    testWidgets("the Add sheet's two doors", (tester) async {
      showState(ChatGeneralDataListState(status: _loaded, chatList: [_nino]));
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home.addPerson')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I got an invite'));
      await tester.pumpAndSettle();
      expect(find.text('got invite flow'), findsOneWidget);
    });
  });

  group('Open', () {
    testWidgets('the Open tile opens Open', (tester) async {
      showState(ChatGeneralDataListState(status: _loaded, chatList: [_nino]));
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('tile.home.open')));
      await tester.pumpAndSettle();
      expect(find.text('open flow'), findsOneWidget);
    });
  });

  test('trust comes from the setup status and the verified flags', () {
    expect(HomePage.trustOf(_mom, const {}), PersonTrust.waiting);
    expect(HomePage.trustOf(_nino, const {}), PersonTrust.checked);
    expect(HomePage.trustOf(_tamar, const {'tamar'}), PersonTrust.notChecked);
  });
}
