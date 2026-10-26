import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late List<String> pasted;
  late String? clipboard;

  setUp(() {
    chatList = _MockChatList();
    pasted = [];
    clipboard = null;
    FuzzzyCastThrottle.reset();
  });

  void showState(ChatGeneralDataListState state) =>
      when(() => chatList.state).thenReturn(state);

  Future<void> pumpHome(
    WidgetTester tester, {
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
    bool castOn = false,
    bool pastedIsLink = true,
  }) async {
    tester.view.physicalSize =
        const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({'fuzzzy_cast_enabled': castOn});
    final preferences =
        PreferencesService(await SharedPreferences.getInstance());

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      // An empty clipboard answers nothing at all, as the platforms do.
      (call) async => call.method == 'Clipboard.getData' && clipboard != null
          ? <String, dynamic>{'text': clipboard}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    Widget stub(String name) => Scaffold(body: Text(name));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: AppRouter.home,
          builder: (_, __) => Scaffold(
            body: HomePage(
              onPastedText: (text) {
                pasted.add(text);
                return pastedIsLink;
              },
            ),
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
          path: AppRouter.basics,
          builder: (_, __) => stub('password flow'),
        ),
        GoRoute(
          path: AppRouter.person,
          builder: (_, state) =>
              stub('page of ${state.uri.queryParameters['chat']}'),
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

    testWidgets('a waiting person opens their page (with the waiting card)',
        (tester) async {
      showState(
        ChatGeneralDataListState(status: _loaded, chatList: [_mom, _nino]),
      );
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('person.mom')));
      await tester.pumpAndSettle();
      expect(find.text('page of ${_mom.chatId}'), findsOneWidget);
    });

    testWidgets('a connected person opens their page', (tester) async {
      showState(
        ChatGeneralDataListState(status: _loaded, chatList: [_mom, _nino]),
      );
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('person.nino')));
      await tester.pumpAndSettle();
      expect(find.text('page of ${_nino.chatId}'), findsOneWidget);
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

    testWidgets('a connected person opens their page, with Lock',
        (tester) async {
      showState(ChatGeneralDataListState(status: _loaded, chatList: [_nino]));
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('tile.home.lock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lockWho.nino')));
      await tester.pumpAndSettle();
      expect(find.text('page of ${_nino.chatId}'), findsOneWidget);
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
    testWidgets('a pasted link goes the way a tapped link goes',
        (tester) async {
      showState(ChatGeneralDataListState(status: _loaded, chatList: [_nino]));
      clipboard = 'https://ink.fuzzzycore.com/invite#RlVaWgEB';
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('tile.home.open')));
      await tester.pumpAndSettle();
      expect(find.text('Open what you got'), findsOneWidget);
      expect(
        find.text('Links and QR codes open here by themselves.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Paste it'));
      await tester.pumpAndSettle();
      expect(pasted, ['https://ink.fuzzzycore.com/invite#RlVaWgEB']);
      expect(find.text('Open what you got'), findsNothing);
    });

    testWidgets('nothing to paste says so and stays', (tester) async {
      showState(ChatGeneralDataListState(status: _loaded, chatList: [_nino]));
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('tile.home.open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      expect(
        find.text('Nothing to paste. Copy the locked text first.'),
        findsOneWidget,
      );
      expect(pasted, isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets("text that is not a link points to the person's page",
        (tester) async {
      showState(ChatGeneralDataListState(status: _loaded, chatList: [_nino]));
      clipboard = 'Fuzz/RlVaWgED';
      await pumpHome(tester, pastedIsLink: false);
      await tester.tap(find.byKey(const Key('tile.home.open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      expect(
        find.text("Paste a link here. Locked text opens on the person's page."),
        findsOneWidget,
      );
      expect(find.text('Open what you got'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('"Locked with a password" opens the password flow',
        (tester) async {
      showState(ChatGeneralDataListState(status: _loaded, chatList: [_nino]));
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('tile.home.open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open.password')));
      await tester.pumpAndSettle();
      expect(find.text('password flow'), findsOneWidget);
    });
  });

  test('trust comes from the setup status and the verified flags', () {
    expect(HomePage.trustOf(_mom, const {}), PersonTrust.waiting);
    expect(HomePage.trustOf(_nino, const {}), PersonTrust.checked);
    expect(HomePage.trustOf(_tamar, const {'tamar'}), PersonTrust.notChecked);
  });
}
