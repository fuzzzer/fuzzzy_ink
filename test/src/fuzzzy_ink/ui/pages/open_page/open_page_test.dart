import 'dart:async';

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

import '../../../../../helpers/redesign_harness.dart';

class _MockOpen extends MockCubit<OpenFlowState> implements OpenFlowCubit {}

class _MockChatFiles extends MockCubit<ChatFileState>
    implements ChatFileCubit {}

final _nino = ChatGeneralData(
  chatId: '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d',
  chatName: 'Nino',
  setupStatus: ChatSetupStatus.connected,
  didAcceptInvitation: false,
);

void main() {
  late _MockOpen cubit;
  late _MockChatFiles chatFiles;
  late String? clipboard;

  setUpAll(() => registerFallbackValue(const OpenPastedText('')));

  setUp(() {
    cubit = _MockOpen();
    chatFiles = _MockChatFiles();
    clipboard = null;
    FuzzzyCastThrottle.reset();
    when(() => chatFiles.state).thenReturn(const ChatFileState());
    when(() => cubit.open(any())).thenAnswer((_) async {});
    when(() => cubit.openWithPassword(any())).thenAnswer((_) async {});
    when(() => cubit.startOver()).thenAnswer((_) async {});
  });

  void show(OpenFlowState state) => when(() => cubit.state).thenReturn(state);

  Future<void> pumpOpen(
    WidgetTester tester, {
    FuzzzySkin skin = FuzzzySkin.night,
    bool castOn = false,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData' && clipboard != null
          ? <String, dynamic>{'text': clipboard}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpRedesign(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<OpenFlowCubit>.value(value: cubit),
          BlocProvider<ChatFileCubit>.value(value: chatFiles),
        ],
        child: const OpenFlowView(),
      ),
      skin: skin,
      castOn: castOn,
      surface: const Size(390, 844),
    );
    await tester.pump();
  }

  group('Open what you got', () {
    for (final skin in redesignSkins) {
      testWidgets('Paste it, Choose a file, and links by themselves ($skin)',
          (tester) async {
        show(const OpenFlowState());
        await pumpOpen(tester, skin: skin);
        expect(find.text('Open what you got'), findsOneWidget);
        expect(find.text('Paste it'), findsOneWidget);
        expect(find.text('Locked text, invite or reply'), findsOneWidget);
        expect(find.text('Choose a file'), findsOneWidget);
        expect(find.text('A .fuzz file'), findsOneWidget);
        expect(
          find.text(
            'Links and QR codes come here. Nothing opens until you tap Open.',
          ),
          findsOneWidget,
        );
        expect(find.byType(SensitiveScreen), findsNothing);
      });
    }

    Future<void> tapOpen(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('btn.open.pasteBox.open')));
      await tester.pump();
    }

    String pasteBoxText(WidgetTester tester) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('field.open.pasteBox.text')),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    testWidgets(
        'the clipboard is read only on the tap, shown in the box, and '
        'opened only on Open', (tester) async {
      show(const OpenFlowState());
      clipboard = '  Fuzz/AwEC ';
      await pumpOpen(tester);
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      expect(
        find.text('Found in what you copied. Check it, or paste your own.'),
        findsOneWidget,
      );
      expect(pasteBoxText(tester), 'Fuzz/AwEC');
      verifyNever(() => cubit.open(any()));
      await tapOpen(tester);
      final request = verify(() => cubit.open(captureAny())).captured.single
          as OpenPastedText;
      expect(request.text, 'Fuzz/AwEC');
    });

    testWidgets('a whole copied message: only its locked part goes in the box',
        (tester) async {
      show(const OpenFlowState());
      clipboard = 'Nino: here it is "https://ink.fuzzzycore.com/message#AwEC". '
          'Open it tonight';
      await pumpOpen(tester);
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      expect(
        pasteBoxText(tester),
        'https://ink.fuzzzycore.com/message#AwEC',
      );
    });

    testWidgets(
        'two locked parts in one copy: "2 found", one at a time, each '
        'opens', (tester) async {
      show(const OpenFlowState());
      clipboard = 'first Fuzz/AwEC then Fuzz/AQE';
      await pumpOpen(tester);
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      expect(
        find.text(
          '2 found in what you copied. This is 1 of 2: open it, then come '
          'back for the next.',
        ),
        findsOneWidget,
      );
      expect(pasteBoxText(tester), 'Fuzz/AwEC');
      await tester.tap(find.byKey(const Key('btn.open.pasteBox.next')));
      await tester.pump();
      expect(pasteBoxText(tester), 'Fuzz/AQE');
      expect(find.textContaining('This is 2 of 2'), findsOneWidget);
      await tapOpen(tester);
      final request = verify(() => cubit.open(captureAny())).captured.single
          as OpenPastedText;
      expect(request.text, 'Fuzz/AQE');
      await tester.tap(find.byKey(const Key('btn.open.pasteBox.next')));
      await tester.pump();
      expect(pasteBoxText(tester), 'Fuzz/AwEC');
    });

    testWidgets('one locked part: no "next"', (tester) async {
      show(const OpenFlowState());
      clipboard = 'Fuzz/AwEC';
      await pumpOpen(tester);
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      expect(find.byKey(const Key('btn.open.pasteBox.next')), findsNothing);
    });

    testWidgets(
        'nothing locked in what was copied: the box stays empty for a '
        'paste by hand', (tester) async {
      show(const OpenFlowState());
      clipboard = 'my bank password is 1234';
      await pumpOpen(tester);
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      expect(
        find.text(
          'What you copied has nothing locked in it. Paste it yourself.',
        ),
        findsOneWidget,
      );
      expect(pasteBoxText(tester), isEmpty);
      expect(find.text('my bank password is 1234'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('field.open.pasteBox.text')),
        ' Fuzz/AQE ',
      );
      await tester.pump();
      await tapOpen(tester);
      final request = verify(() => cubit.open(captureAny())).captured.single
          as OpenPastedText;
      expect(request.text, 'Fuzz/AQE');
    });

    testWidgets('back from the box returns to Open what you got',
        (tester) async {
      show(const OpenFlowState());
      clipboard = 'Fuzz/AwEC';
      await pumpOpen(tester);
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('iconbtn.open.pasteBox.back')));
      await tester.pump();
      expect(find.text('Open what you got'), findsOneWidget);
      verifyNever(() => cubit.open(any()));
    });

    group("iPhone's own Paste button (final regression 2026-10-26)", () {
      const codec = StandardMethodCodec();
      late List<MethodCall> platformViewCalls;

      setUp(() => InkPasteButton.debugIsAvailable = true);
      tearDown(() => InkPasteButton.debugIsAvailable = null);

      Future<void> pumpWithPlatformViews(WidgetTester tester) async {
        platformViewCalls = [];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (call) async {
            platformViewCalls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform_views, null),
        );
        await pumpOpen(tester);
      }

      Future<void> pasteFromSystem(WidgetTester tester, String? text) async {
        final created = platformViewCalls
            .firstWhere((call) => call.method == 'create')
            .arguments as Map<Object?, Object?>;
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          '${InkPasteButton.viewType}/${created['id']}',
          codec.encodeMethodCall(MethodCall('pasted', text)),
          (_) {},
        );
        await tester.pump();
      }

      testWidgets(
          'sits on the Paste it row and puts what it pastes in the box, '
          'without reading the clipboard itself', (tester) async {
        show(const OpenFlowState());
        clipboard = 'not read';
        await pumpWithPlatformViews(tester);
        expect(find.byKey(const Key('paste.open')), findsOneWidget);
        final created = platformViewCalls.singleWhere(
          (call) => call.method == 'create',
        );
        expect(
          (created.arguments as Map<Object?, Object?>)['viewType'],
          InkPasteButton.viewType,
        );

        await pasteFromSystem(tester, '  Fuzz/AwEC ');
        verifyNever(() => cubit.open(any()));
        await tester.tap(find.byKey(const Key('btn.open.pasteBox.open')));
        await tester.pump();
        final request = verify(() => cubit.open(captureAny())).captured.single
            as OpenPastedText;
        expect(request.text, 'Fuzz/AwEC');
      });

      testWidgets('a paste with no text opens an empty box', (tester) async {
        show(const OpenFlowState());
        await pumpWithPlatformViews(tester);
        await pasteFromSystem(tester, null);
        expect(
          find.byKey(const Key('field.open.pasteBox.text')),
          findsOneWidget,
        );
        verifyNever(() => cubit.open(any()));
      });
    });

    testWidgets('elsewhere there is no system button; the row pastes',
        (tester) async {
      show(const OpenFlowState());
      await pumpOpen(tester);
      expect(find.byKey(const Key('paste.open')), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
    });

    testWidgets('nothing copied: an empty box, and Open waits for text',
        (tester) async {
      show(const OpenFlowState());
      await pumpOpen(tester);
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      expect(find.byKey(const Key('field.open.pasteBox.text')), findsOneWidget);
      expect(
        find.text('Found in what you copied. Check it, or paste your own.'),
        findsNothing,
      );
      await tapOpen(tester);
      verifyNever(() => cubit.open(any()));
    });
  });

  testWidgets(
      'a message link asks "Open the message from Nino?" and opens only on '
      'Open (security review 2026-10-26)', (tester) async {
    when(() => cubit.confirmOpen()).thenAnswer((_) async {});
    show(
      OpenFlowState(
        phase: OpenPhase.confirmMessage,
        chat: _nino,
        pendingMessage: 'Fuzz/AwEC',
      ),
    );
    await pumpOpen(tester);
    expect(find.text('Open the message from Nino?'), findsOneWidget);
    verifyNever(() => cubit.confirmOpen());
    await tester.tap(find.byKey(const Key('btn.open.confirm.open')));
    await tester.pump();
    verify(() => cubit.confirmOpen()).called(1);
  });

  testWidgets(
      "a person's .fuzz file handed over by another app asks \"Open the "
      'file from Nino?" and opens only on Open; Not now leaves',
      (tester) async {
    when(() => cubit.confirmOpen()).thenAnswer((_) async {});
    show(
      OpenFlowState(
        phase: OpenPhase.confirmMessage,
        chat: _nino,
        pendingFilePath: '/support/handoff/1_0/photo.jpg.fuzz',
      ),
    );
    await pumpOpen(tester);
    expect(find.text('Open the file from Nino?'), findsOneWidget);
    expect(find.byKey(const Key('btn.open.confirm.notNow')), findsOneWidget);
    verifyNever(() => cubit.confirmOpen());
    await tester.tap(find.byKey(const Key('btn.open.confirm.open')));
    await tester.pump();
    verify(() => cubit.confirmOpen()).called(1);
  });

  testWidgets('reading says so', (tester) async {
    show(const OpenFlowState(phase: OpenPhase.reading));
    await pumpOpen(tester);
    expect(find.text('Reading…'), findsOneWidget);
  });

  testWidgets('opening a file: real progress and Cancel, no Pause',
      (tester) async {
    show(
      OpenFlowState(
        phase: OpenPhase.working,
        chat: _nino,
        workingName: 'lease.pdf.fuzz',
        progress: 0.6,
      ),
    );
    await pumpOpen(tester);
    expect(find.text('Opening'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    await tester.tap(find.byKey(const Key('btn.open.working.cancel')));
    verify(() => cubit.cancel()).called(1);
  });

  group('password items', () {
    testWidgets("What's the password? (private)", (tester) async {
      show(
        const OpenFlowState(
          phase: OpenPhase.password,
          pendingPassword: PendingPasswordItem.text('Fuzz/BQ'),
        ),
      );
      await pumpOpen(tester);
      expect(find.byType(SensitiveScreen), findsOneWidget);
      expect(find.text('Locked with a password'), findsOneWidget);
      expect(find.text("What's the password?"), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('field.open.password')),
        'tulip',
      );
      await tester.tap(find.byKey(const Key('btn.open.password.open')));
      verify(() => cubit.openWithPassword('tulip')).called(1);
    });

    testWidgets('a wrong one: one line and one firm buzz', (tester) async {
      const asking = OpenFlowState(
        phase: OpenPhase.password,
        pendingPassword: PendingPasswordItem.text('Fuzz/BQ'),
      );
      final states = StreamController<OpenFlowState>();
      whenListen(cubit, states.stream, initialState: asking);
      await pumpOpen(tester);
      // After the pump: it replaces the clipboard stub on the same channel.
      final haptics = recordHaptics(tester);
      states.add(
        const OpenFlowState(
          phase: OpenPhase.password,
          pendingPassword: PendingPasswordItem.text('Fuzz/BQ'),
          isPasswordWrong: true,
        ),
      );
      await tester.pump();
      expect(
        find.text("That doesn't open it. Check it and try again."),
        findsOneWidget,
      );
      expect(haptics, ['HapticFeedbackType.heavyImpact']);
      await states.close();
    });
  });

  group('opened message', () {
    for (final skin in redesignSkins) {
      testWidgets('private, not selectable, No copy with Why? ($skin)',
          (tester) async {
        show(
          OpenFlowState(
            phase: OpenPhase.openedText,
            chat: _nino,
            openedText: 'see you at 6',
            historyRowId: 3,
          ),
        );
        await pumpOpen(tester, skin: skin, castOn: true);
        expect(find.byType(SensitiveScreen), findsOneWidget);
        expect(find.text('From Nino'), findsOneWidget);
        expect(find.text("Just now · kept in Nino's history"), findsOneWidget);
        expect(find.text('see you at 6'), findsOneWidget);
        expect(find.byType(SelectableText), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        expect(find.byType(SelectionArea), findsNothing);
        expect(find.text('NO COPY'), findsOneWidget);
        expect(find.byType(WhyLink), findsOneWidget);
        // Never Fuzzz on a private screen, even with Fuzzzy Cast on.
        expect(find.byType(CastFigure), findsNothing);
      });
    }

    testWidgets('with a password: not kept', (tester) async {
      show(
        const OpenFlowState(phase: OpenPhase.openedText, openedText: 'hello'),
      );
      await pumpOpen(tester);
      expect(find.text('Opened with a password'), findsOneWidget);
      expect(find.text('Just now · not kept'), findsOneWidget);
    });
  });

  group('opened file', () {
    OpenFlowState fileState(String name) => OpenFlowState(
          phase: OpenPhase.openedFile,
          chat: _nino,
          openedFile: OpenedFile(
            name: name,
            keptRow: MessageData(
              id: 4,
              chatId: _nino.chatId,
              type: MessageType.file,
              encryptedMessage: 'chats/x/$name.fuzz',
              decryptedMessage: '',
              sentAt: DateTime(2026),
              isSent: false,
              keptFileKey: 'a2V5',
            ),
          ),
        );

    testWidgets('a picture: Open in the app and Save, private', (tester) async {
      show(fileState('beach.jpg'));
      await pumpOpen(tester);
      expect(find.byType(SensitiveScreen), findsOneWidget);
      expect(find.text('beach.jpg'), findsOneWidget);
      expect(find.byKey(const Key('btn.opened.file.open')), findsOneWidget);
      expect(find.byKey(const Key('btn.opened.file.save')), findsOneWidget);
      expect(
        find.text("Save gives you a normal copy. Then it's yours."),
        findsOneWidget,
      );
    });

    testWidgets('any other kind (or a risky one): Save only, with why',
        (tester) async {
      show(fileState('setup.exe'));
      await pumpOpen(tester);
      expect(find.byKey(const Key('btn.opened.file.open')), findsNothing);
      expect(find.byKey(const Key('opened.file.noPreview')), findsOneWidget);
      expect(find.byKey(const Key('btn.opened.file.save')), findsOneWidget);
    });
  });

  group("can't open", () {
    final cases = <(OpenProblem, ChatGeneralData?, String, String, String)>[
      (
        OpenProblem.alreadyOpened,
        _nino,
        'Already opened',
        "Each locked thing opens once. It's in Nino's history.",
        'Go to Nino',
      ),
      (
        OpenProblem.notFromYourPeople,
        null,
        'Not from your people',
        'Ask them for an invite first.',
        'Add a person',
      ),
      (
        OpenProblem.damaged,
        null,
        "Can't open this",
        'It may be cut off or for someone else. Ask them to send it again.',
        'Back',
      ),
      (
        OpenProblem.tooOld,
        _nino,
        'Too old to open',
        'Ask Nino to lock it again.',
        'Go to Nino',
      ),
      (
        OpenProblem.newerApp,
        null,
        'Needs a newer Fuzzzy Ink',
        'Update the app, then try again.',
        'OK',
      ),
      (
        OpenProblem.ownInvite,
        null,
        "That's your own invite",
        'Send it to the other person.',
        'OK',
      ),
      (
        OpenProblem.alreadyConnected,
        _nino,
        'Already connected',
        'You and Nino are connected already.',
        'Go to Nino',
      ),
      (
        OpenProblem.notFuzzzy,
        null,
        "This isn't from Fuzzzy Ink",
        'Open locked text, an invite or a reply.',
        'Back',
      ),
      (
        OpenProblem.stillArriving,
        _nino,
        'Still arriving',
        'Wait until the file has fully arrived, then try again.',
        'Back',
      ),
      (
        OpenProblem.askResend,
        _nino,
        "This file didn't open",
        "It can't open on this phone now. Ask them to send it again.",
        'Back',
      ),
    ];

    for (final (problem, chat, title, line, button) in cases) {
      for (final skin in redesignSkins) {
        testWidgets('$problem ($skin)', (tester) async {
          show(
            OpenFlowState(
              phase: OpenPhase.problem,
              problem: problem,
              chat: chat,
            ),
          );
          await pumpOpen(tester, skin: skin);
          expect(find.text(title), findsOneWidget);
          expect(find.text(line), findsOneWidget);
          expect(find.text(button), findsOneWidget);
          expect(find.byType(SensitiveScreen), findsNothing);
          expect(
            find.byType(WhyLink),
            problem == OpenProblem.alreadyOpened
                ? findsOneWidget
                : findsNothing,
          );
        });
      }
    }

    testWidgets('Back starts over', (tester) async {
      show(
        const OpenFlowState(
          phase: OpenPhase.problem,
          problem: OpenProblem.damaged,
        ),
      );
      await pumpOpen(tester);
      await tester.tap(find.text('Back'));
      verify(() => cubit.startOver()).called(1);
    });

    testWidgets('Fuzzz is sad when Fuzzzy Cast is on', (tester) async {
      show(
        const OpenFlowState(
          phase: OpenPhase.problem,
          problem: OpenProblem.damaged,
        ),
      );
      await pumpOpen(tester, castOn: true);
      expect(find.byType(CastFigure), findsOneWidget);
      expect(
        find.byKey(const Key('open.problem.damaged')),
        findsNothing,
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });

  group('invites and replies go on to adding a person', () {
    Future<GoRouter> pumpRouted(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences =
          PreferencesService(await SharedPreferences.getInstance());
      final router = GoRouter(
        initialLocation: AppRouter.open,
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('home')),
          GoRoute(
            path: AppRouter.open,
            builder: (_, __) => MultiBlocProvider(
              providers: [
                BlocProvider<OpenFlowCubit>.value(value: cubit),
                BlocProvider<ChatFileCubit>.value(value: chatFiles),
              ],
              child: const OpenFlowView(),
            ),
          ),
          GoRoute(
            path: AppRouter.chatAccept,
            builder: (_, state) => Text('accept ${state.extra}'),
          ),
          GoRoute(
            path: AppRouter.personAnsweredTwice,
            builder: (_, state) => Text(
              'answered twice: ${(state.extra! as ChatGeneralData).chatName}',
            ),
          ),
          GoRoute(
            path: AppRouter.chatInvitation,
            builder: (_, state) => Text(
              'reply for '
              '${(state.extra! as ChatInvitationPagePayload).chatName}: '
              '${(state.extra! as ChatInvitationPagePayload).prefillAcceptanceContent}',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider(
          create: (_) =>
              FuzzzyCastSettingsCubit(preferencesService: preferences),
          child: MaterialApp.router(
            theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
            localizationsDelegates:
                FuzzzyInkLocalizations.localizationsDelegates,
            supportedLocales: FuzzzyInkLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      return router;
    }

    testWidgets('an invite opens "Who sent it?"', (tester) async {
      final states = StreamController<OpenFlowState>();
      whenListen(cubit, states.stream, initialState: const OpenFlowState());
      await pumpRouted(tester);
      states.add(const OpenFlowState(route: OpenRouteInvite('Fuzz/AQE')));
      await tester.pumpAndSettle();
      expect(find.text('accept Fuzz/AQE'), findsOneWidget);
      verify(() => cubit.routeTaken()).called(1);
      await states.close();
    });

    testWidgets('a reply finishes connecting', (tester) async {
      final states = StreamController<OpenFlowState>();
      whenListen(cubit, states.stream, initialState: const OpenFlowState());
      await pumpRouted(tester);
      states.add(
        OpenFlowState(
          route: OpenRouteReply(chat: _nino, acceptance: 'Fuzz/AgE'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('reply for Nino: Fuzz/AgE'), findsOneWidget);
      await states.close();
    });

    testWidgets('a second reply goes to "Someone else may have answered"',
        (tester) async {
      final states = StreamController<OpenFlowState>();
      whenListen(cubit, states.stream, initialState: const OpenFlowState());
      await pumpRouted(tester);
      states.add(OpenFlowState(route: OpenRouteSecondReply(_nino)));
      await tester.pumpAndSettle();
      expect(find.text('answered twice: Nino'), findsOneWidget);
      verify(() => cubit.routeTaken()).called(1);
      await states.close();
    });
  });
}
