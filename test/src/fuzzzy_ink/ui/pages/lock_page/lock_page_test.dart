import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_cast/fuzzzy_cast.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/redesign_harness.dart';

class _MockLock extends MockCubit<LockFlowState> implements LockFlowCubit {}

/// Records copies without a clipboard or a clear timer.
class _FakeGuard extends ClipboardGuard {
  final copies = <(String, CopyContent)>[];

  @override
  Future<bool> copy(String text, CopyContent content) async {
    copies.add((text, content));
    return policy.allows(content);
  }
}

final _nino = ChatGeneralData(
  chatId: '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d',
  chatName: 'Nino',
  setupStatus: ChatSetupStatus.connected,
  didAcceptInvitation: false,
);

const _lockedText =
    'Fuzz/RlVaWgEDAAMBAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4fICEiIyQl';

void main() {
  late _MockLock cubit;
  late _FakeGuard guard;
  late ClipboardGuard realGuard;

  setUp(() {
    cubit = _MockLock();
    guard = _FakeGuard();
    realGuard = CopyGuard.clipboardGuard;
    CopyGuard.clipboardGuard = guard;
    sl.safeRegisterSingleton<PasswordStrengthService>(
      PasswordStrengthService(),
    );
    FuzzzyCastThrottle.reset();
    when(
      () => cubit.lock(
        text: any(named: 'text'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(() => cubit.chooseFile(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    CopyGuard.clipboardGuard = realGuard;
    sl.unregister<PasswordStrengthService>();
  });

  void show(LockFlowState state) => when(() => cubit.state).thenReturn(state);

  Future<void> pumpFlow(
    WidgetTester tester, {
    ChatGeneralData? chat,
    FuzzzySkin skin = FuzzzySkin.night,
    bool castOn = false,
    bool reduceMotion = false,
  }) async {
    await pumpRedesign(
      tester,
      BlocProvider<LockFlowCubit>.value(
        value: cubit,
        child: LockFlowView(chat: chat),
      ),
      skin: skin,
      castOn: castOn,
      reduceMotion: reduceMotion,
      surface: const Size(390, 844),
    );
    await tester.pump();
  }

  group('What', () {
    for (final skin in redesignSkins) {
      testWidgets('a message for Nino, private while typing ($skin)',
          (tester) async {
        show(const LockFlowState());
        await pumpFlow(tester, chat: _nino, skin: skin);

        expect(find.text('Lock for Nino'), findsOneWidget);
        expect(find.text('STEP 2 OF 2 · WHAT'), findsOneWidget);
        expect(find.text('Only Nino can open it, once.'), findsOneWidget);
        expect(find.byType(SensitiveScreen), findsOneWidget);

        // Paste stays, copy and cut go: the guard's menu, below the
        // screen's shortcut block.
        final field = tester.widget<TextField>(
          find.byKey(const Key('field.lock.message')),
        );
        expect(
          field.contextMenuBuilder,
          CopyGuard.plaintextContextMenuBuilder,
        );

        await tester.enterText(
          find.byKey(const Key('field.lock.message')),
          'see you at 6',
        );
        await tester.tap(find.byKey(const Key('btn.lock.do')));
        verify(() => cubit.lock(text: 'see you at 6')).called(1);
      });
    }

    for (final (failure, line) in [
      (LockFailure.writeSomethingFirst, 'Write something first.'),
      (LockFailure.chooseFileFirst, 'Choose a file first.'),
      (LockFailure.stopped, 'Stopped. Nothing was kept.'),
      (LockFailure.failed, "Couldn't lock it. Try again."),
    ]) {
      testWidgets('$failure is one short line', (tester) async {
        show(LockFlowState(failure: failure));
        await pumpFlow(tester, chat: _nino);
        expect(find.text(line), findsOneWidget);
      });
    }

    testWidgets('File: choose, or drop it on a computer', (tester) async {
      show(const LockFlowState(kind: LockKind.file));
      await pumpFlow(tester, chat: _nino);
      expect(find.text('Choose a file'), findsOneWidget);
      expect(find.text('Or drop it here on a computer'), findsOneWidget);
    });

    testWidgets('File: the chosen file with Change', (tester) async {
      show(
        const LockFlowState(
          kind: LockKind.file,
          file: LockFileChoice(filePath: '/x/beach-photo.jpg', size: 2400000),
          failure: LockFailure.chooseFileFirst,
        ),
      );
      await pumpFlow(tester, chat: _nino);
      expect(find.text('beach-photo.jpg'), findsOneWidget);
      expect(find.text('2.3 MB'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('the Message | File switch tells the cubit', (tester) async {
      show(const LockFlowState());
      await pumpFlow(tester, chat: _nino);
      await tester.tap(find.text('File'));
      verify(() => cubit.chooseKind(LockKind.file)).called(1);
    });

    testWidgets('with a password: strength, "Say the password", Why?',
        (tester) async {
      show(const LockFlowState());
      await pumpFlow(tester);

      expect(find.text('Lock with a password'), findsOneWidget);
      expect(find.text("Say the password. Don't send it."), findsOneWidget);
      expect(find.byType(WhyLink), findsOneWidget);
      expect(find.text('Only Nino can open it, once.'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('field.lock.password')),
        'abc',
      );
      await tester.pump();
      expect(find.text('Weak'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('field.lock.password')),
        'violet-harbor-lantern-91',
      );
      await tester.pump();
      // The app's one meter, the same as the master password's.
      expect(find.byKey(const Key('meter.lock')), findsOneWidget);
      expect(find.byType(PasswordMeter), findsOneWidget);
      expect(find.text('Weak'), findsNothing);
    });

    testWidgets('a password below Good says what it needs', (tester) async {
      show(const LockFlowState(failure: LockFailure.passwordNotGood));
      await pumpFlow(tester);
      expect(find.text('It needs to reach Good.'), findsOneWidget);
    });

    testWidgets('Georgian fits', (tester) async {
      show(const LockFlowState());
      await pumpRedesign(
        tester,
        BlocProvider<LockFlowCubit>.value(
          value: cubit,
          child: const LockFlowView(chat: null),
        ),
        locale: const Locale('ka'),
        textScale: 1.3,
        surface: const Size(360, 740),
      );
      await tester.pump();
      expect(find.text('ჩაკეტვა'), findsWidgets);
    });
  });

  group('Locking', () {
    testWidgets('real progress, Pause / Go on and Cancel', (tester) async {
      show(
        const LockFlowState(
          phase: LockPhase.working,
          kind: LockKind.file,
          file: LockFileChoice(filePath: '/x/beach-photo.jpg', size: 10),
          progress: 0.42,
        ),
      );
      await pumpFlow(tester, chat: _nino);
      expect(find.text('Locking'), findsOneWidget);
      expect(find.text('beach-photo.jpg'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.byType(SensitiveScreen), findsNothing);

      await tester.tap(find.byKey(const Key('btn.lock.working.pause')));
      verify(() => cubit.pause()).called(1);
      await tester.tap(find.byKey(const Key('btn.lock.working.cancel')));
      verify(() => cubit.cancel()).called(1);
    });

    testWidgets('paused: Go on', (tester) async {
      show(
        const LockFlowState(
          phase: LockPhase.working,
          file: LockFileChoice(filePath: '/x/a.jpg', size: 10),
          isPaused: true,
        ),
      );
      await pumpFlow(tester, chat: _nino);
      expect(find.text('Go on'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn.lock.working.resume')));
      verify(() => cubit.resume()).called(1);
    });

    testWidgets('Fuzzz keeps watch when Fuzzzy Cast is on', (tester) async {
      show(
        const LockFlowState(
          phase: LockPhase.working,
          file: LockFileChoice(filePath: '/x/a.jpg', size: 10),
        ),
      );
      await pumpFlow(tester, chat: _nino, castOn: true);
      expect(find.byType(CastFigure), findsOneWidget);
      expect(find.byKey(const Key('lock.working.glyph')), findsNothing);
      expect(find.text('Starting…'), findsOneWidget);
    });
  });

  group('Locked', () {
    const lockedMessage = LockFlowState(
      phase: LockPhase.locked,
      item: LockedItem(lockedText: _lockedText, historyRowId: 4),
    );

    for (final skin in redesignSkins) {
      testWidgets(
          'message: the lock snaps, the locked text, Share and Copy '
          '($skin)', (tester) async {
        show(lockedMessage);
        await pumpFlow(tester, chat: _nino, skin: skin);

        expect(find.text('Locked for Nino'), findsOneWidget);
        expect(find.text('Now send it.'), findsOneWidget);
        expect(find.byType(LockSnapGlyph), findsOneWidget);
        expect(find.byType(LockedTextPreview), findsOneWidget);
        expect(find.byType(SensitiveScreen), findsNothing);
        expect(find.text('Copy locked text'), findsOneWidget);
        await tester.pumpAndSettle();
      });
    }

    testWidgets(
        'Copy locked text copies only the locked text, "Copied" in '
        'place', (tester) async {
      show(lockedMessage);
      await pumpFlow(tester, chat: _nino);
      await tester.tap(find.byKey(const Key('btn.locked.copy')));
      await tester.pump();
      expect(guard.copies, [(_lockedText, CopyContent.sealedMessage)]);
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(InkMotionTiming.confirmHold);
      await tester.pumpAndSettle();
      expect(find.text('Copied'), findsNothing);
    });

    testWidgets('a share that finished: Share again, Done becomes main',
        (tester) async {
      final shared = <bool>[];
      show(lockedMessage);
      await pumpRedesign(
        tester,
        LockedView(
          chat: _nino,
          state: lockedMessage,
          onShared: ({copied = false}) => shared.add(copied),
          onDone: () {},
        ),
        surface: const Size(390, 844),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn.locked.share')));
      await tester.pumpAndSettle();
      expect(find.text('Share locked message'), findsOneWidget);
      expect(find.text('Only Nino can open it.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('share.copy')));
      await tester.pump();
      await tester.pump(InkMotionTiming.sheetCloseAfterCopy);
      await tester.pumpAndSettle();
      expect(shared, [true], reason: 'it went out as Copy as text');

      await pumpRedesign(
        tester,
        LockedView(
          chat: _nino,
          state: const LockFlowState(
            phase: LockPhase.locked,
            item: LockedItem(lockedText: _lockedText),
            isShared: true,
          ),
          onShared: ({copied = false}) {},
          onDone: () {},
        ),
        surface: const Size(390, 844),
      );
      await tester.pumpAndSettle();
      expect(find.text('Share again'), findsOneWidget);
      expect(find.text('Sent to your share menu.'), findsOneWidget);

      // After Copy as text the line says it was copied (QA 2026-10-26).
      await pumpRedesign(
        tester,
        LockedView(
          chat: _nino,
          state: const LockFlowState(
            phase: LockPhase.locked,
            item: LockedItem(lockedText: _lockedText),
            isShared: true,
            sharedByCopy: true,
          ),
          onShared: ({copied = false}) {},
          onDone: () {},
        ),
        surface: const Size(390, 844),
      );
      await tester.pumpAndSettle();
      expect(find.text('Copied. It stays locked.'), findsOneWidget);
      expect(find.text('Sent to your share menu.'), findsNothing);
      final done = tester.widget<FuzzzyButton>(
        find.ancestor(
          of: find.text('Done'),
          matching: find.byType(FuzzzyButton),
        ),
      );
      expect(done.variant, FuzzzyButtonVariant.primary);
    });

    testWidgets('file: the .fuzz card and Save locked file, no copy',
        (tester) async {
      show(
        const LockFlowState(
          phase: LockPhase.locked,
          item: LockedItem(
            lockedFilePath: '/sealed/beach-photo.jpg.fuzz',
            fileName: 'beach-photo.jpg',
            fileSize: 2048,
          ),
        ),
      );
      await pumpFlow(tester, chat: _nino);
      expect(find.text('beach-photo.jpg.fuzz'), findsOneWidget);
      expect(find.text('Save locked file'), findsOneWidget);
      expect(find.text('Copy locked text'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('with a password: its own title and the reminder',
        (tester) async {
      show(
        const LockFlowState(
          phase: LockPhase.locked,
          item: LockedItem(lockedText: _lockedText),
        ),
      );
      await pumpFlow(tester);
      expect(find.text('Locked with a password'), findsOneWidget);
      expect(find.text("Say the password. Don't send it."), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn.locked.copy')));
      await tester.pump();
      expect(guard.copies.single.$2, CopyContent.sealedText);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('Fuzzz is "determined" in the picture when Fuzzzy Cast is on',
        (tester) async {
      show(lockedMessage);
      await pumpFlow(tester, chat: _nino, castOn: true);
      expect(find.byType(CastFigure), findsOneWidget);
      expect(find.byType(LockSnapGlyph), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('locking done buzzes once, with reduced motion too',
        (tester) async {
      final haptics = recordHaptics(tester);
      final states = StreamController<LockFlowState>();
      whenListen(cubit, states.stream, initialState: const LockFlowState());
      await pumpFlow(tester, chat: _nino, reduceMotion: true);
      states.add(lockedMessage);
      await tester.pump();
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      await states.close();
      await tester.pumpAndSettle();
    });
  });
}
