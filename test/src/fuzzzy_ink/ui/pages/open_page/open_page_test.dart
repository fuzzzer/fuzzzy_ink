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
          find.text('Links and QR codes open here by themselves.'),
          findsOneWidget,
        );
        expect(find.byType(SensitiveScreen), findsNothing);
      });
    }

    testWidgets('the clipboard is read only on the tap and opened',
        (tester) async {
      show(const OpenFlowState());
      clipboard = '  Fuzz/AwEC ';
      await pumpOpen(tester);
      verifyNever(() => cubit.open(any()));
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      final request = verify(() => cubit.open(captureAny())).captured.single
          as OpenPastedText;
      expect(request.text, 'Fuzz/AwEC');
    });

    testWidgets('nothing to paste says so and stays', (tester) async {
      show(const OpenFlowState());
      await pumpOpen(tester);
      await tester.tap(find.text('Paste it'));
      await tester.pump();
      expect(
        find.text('Nothing to paste. Copy the locked text first.'),
        findsOneWidget,
      );
      verifyNever(() => cubit.open(any()));
      await tester.pump(const Duration(seconds: 3));
    });
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
  });
}
