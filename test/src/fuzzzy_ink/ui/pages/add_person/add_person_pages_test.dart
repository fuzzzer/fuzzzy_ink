import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_cast/fuzzzy_cast.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/people_harness.dart';
import '../../../../../helpers/redesign_harness.dart';

const _invite = 'Fuzz/inviteBlob';
const _reply = 'Fuzz/replyBlob';

final _tamar = personChat(name: 'Tamar');

FuzzzyButton _button(WidgetTester tester, Finder key) => tester.widget(
      find.ancestor(of: key, matching: find.byType(FuzzzyButton)).first,
    );

void main() {
  setUp(FuzzzyCastThrottle.reset);

  group('Send an invite: name', () {
    late MockChatCreationCubit cubit;

    setUp(() {
      cubit = MockChatCreationCubit();
      when(() => cubit.createChat(chatName: any(named: 'chatName')))
          .thenAnswer((_) async {});
    });

    Future<void> pumpName(
      WidgetTester tester, {
      Stream<ChatCreationState> states = const Stream.empty(),
      FuzzzySkin skin = FuzzzySkin.night,
    }) async {
      whenListen(
        cubit,
        states,
        initialState: const ChatCreationState(status: StateStatus.initial),
      );
      await pumpPeople(
        tester,
        BlocProvider<ChatCreationCubit>.value(
          value: cubit,
          child: const ProvidedChatCreationPage(),
        ),
        skin: skin,
      );
    }

    for (final skin in redesignSkins) {
      testWidgets(
          'step 1 of 2: "Who\'s it for?", their name, the steps picture; '
          'Make the invite waits for a name ($skin)', (tester) async {
        await pumpName(tester, skin: skin);
        expect(find.text('STEP 1 OF 2 · NAME'), findsOneWidget);
        expect(find.text("Who's it for?"), findsOneWidget);
        expect(find.text('Only you see it.'), findsOneWidget);
        expect(find.byKey(const Key('steps_picture.sendInvite')), findsOne);
        final make = find.byKey(const Key('btn.sendInvite.make'));
        expect(_button(tester, make).onPressed, isNull);

        await tester.enterText(find.byType(TextField), 'Tamar');
        await tester.pump();
        await tester.tap(make);
        verify(() => cubit.createChat(chatName: 'Tamar')).called(1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a name already used says so in the field', (tester) async {
      await pumpName(
        tester,
        states: Stream.value(
          ChatCreationState(
            status: StateStatus.failed,
            failure: ChatCreationFailure(
              type: ChatCreationFailureType.existingName,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('You already have someone with this name.'),
        findsOneWidget,
      );
    });

    testWidgets('the invite made: on to "Send it to Tamar"', (tester) async {
      await pumpName(
        tester,
        states: Stream.value(
          const ChatCreationState(
            status: StateStatus.success,
            chatName: 'Tamar',
            chatId: peopleChatId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('to /chat/invitation Tamar new'), findsOneWidget);
    });
  });

  group('Send it to Tamar', () {
    late MockInvitationReaderCubit reader;
    late MockHandshakeCubit handshake;

    setUp(() {
      reader = MockInvitationReaderCubit();
      handshake = MockHandshakeCubit();
      whenListen(
        reader,
        const Stream<InvitationReaderState>.empty(),
        initialState: const InvitationReaderState(
          status: StateStatus.success,
          invitation:
              CryptoCoreInvitation(chatId: peopleChatId, content: _invite),
        ),
      );
      when(
        () => handshake.completeHandshake(
          acceptanceContent: any(named: 'acceptanceContent'),
          chatId: any(named: 'chatId'),
        ),
      ).thenAnswer((_) async {});
    });

    Future<void> pumpReady(
      WidgetTester tester, {
      String? reply,
      bool confirmReply = false,
      Stream<HandshakeState> states = const Stream.empty(),
      bool castOn = false,
      FuzzzySkin skin = FuzzzySkin.night,
    }) async {
      whenListen(
        handshake,
        states,
        initialState: const HandshakeState(status: StateStatus.initial),
      );
      await pumpPeople(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider<InvitationReaderCubit>.value(value: reader),
            BlocProvider<HandshakeCubit>.value(value: handshake),
          ],
          child: ProvidedChatInvitationPage(
            payload: ChatInvitationPagePayload(
              chatName: 'Tamar',
              chatId: peopleChatId,
              prefillAcceptanceContent: reply,
              justMade: true,
              confirmReply: confirmReply,
            ),
          ),
        ),
        castOn: castOn,
        skin: skin,
      );
    }

    for (final skin in redesignSkins) {
      testWidgets(
          'step 2 of 2: the steps picture, the two waiting notes, Share '
          'invite, Done for now and "I got Tamar\'s reply" ($skin)',
          (tester) async {
        await pumpReady(tester, skin: skin);
        await tester.pumpAndSettle();
        expect(find.text('STEP 2 OF 2 · SEND'), findsOneWidget);
        expect(find.text('Send it to Tamar'), findsOneWidget);
        expect(find.byKey(const Key('hero.inviteReady')), findsOneWidget);
        expect(find.byKey(const Key('steps_picture.inviteReady')), findsOne);
        expect(
          find.text(
            'Once Tamar replies, you can lock messages for each other.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Send the invite any way, even publicly. It stays safe.'),
          findsOneWidget,
        );
        expect(find.text('Share invite'), findsOneWidget);
        expect(find.text('Done for now'), findsOneWidget);
        expect(find.text("I got Tamar's reply"), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('with Fuzzzy Cast on, Fuzzz takes the picture slot',
        (tester) async {
      await pumpReady(tester, castOn: true);
      expect(find.byType(CastFigure), findsOneWidget);
      expect(find.byKey(const Key('hero.inviteReady')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Share invite opens the Share sheet for the invite',
        (tester) async {
      await pumpReady(tester);
      await tester
          .ensureVisible(find.byKey(const Key('btn.inviteReady.share')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn.inviteReady.share')));
      await tester.pumpAndSettle();
      expect(find.text('Any way. Even publicly.'), findsOneWidget);
      expect(find.text('Copy as text'), findsOneWidget);
    });

    testWidgets('a reply connects at once, then "Connected with Tamar"',
        (tester) async {
      await pumpReady(
        tester,
        reply: _reply,
        states: Stream.fromIterable([
          const HandshakeState(status: StateStatus.loading),
          HandshakeState(
            status: StateStatus.success,
            chatData: personChat(
              name: 'Tamar',
              status: ChatSetupStatus.invited,
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      verify(
        () => handshake.completeHandshake(
          acceptanceContent: _reply,
          chatId: peopleChatId,
        ),
      ).called(1);
      expect(find.text('to /person/connected Tamar'), findsOneWidget);
    });

    testWidgets(
        'a reply that came by link asks "Connect with Tamar?" and connects '
        'only on Connect (security review 2026-10-26)', (tester) async {
      await pumpReady(tester, reply: _reply, confirmReply: true);
      await tester.pumpAndSettle();
      expect(find.text('Connect with Tamar?'), findsOneWidget);
      verifyNever(
        () => handshake.completeHandshake(
          acceptanceContent: any(named: 'acceptanceContent'),
          chatId: any(named: 'chatId'),
        ),
      );
      await tester.tap(find.byKey(const Key('btn.replyLink.connect')));
      await tester.pump();
      verify(
        () => handshake.completeHandshake(
          acceptanceContent: _reply,
          chatId: peopleChatId,
        ),
      ).called(1);
    });

    testWidgets('a reply that does not connect says so and stays',
        (tester) async {
      await pumpReady(
        tester,
        reply: _reply,
        states: Stream.value(
          HandshakeState(
            status: StateStatus.failed,
            failure: ChatCreationFailure(
              type: ChatCreationFailureType.unknown,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text("That reply didn't connect you. Ask for it again."),
        findsOneWidget,
      );
      expect(find.text('Send it to Tamar'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });

  group('I got an invite', () {
    late MockInvitationAcceptanceCubit cubit;

    setUp(() {
      cubit = MockInvitationAcceptanceCubit();
      when(() => cubit.checkInvitation(any()))
          .thenAnswer((_) async => InvitationCheck.good);
      when(
        () => cubit.acceptInvitation(
          invitationContent: any(named: 'invitationContent'),
          chatName: any(named: 'chatName'),
        ),
      ).thenAnswer((_) async {});
    });

    Future<void> pumpGot(
      WidgetTester tester, {
      String? prefill,
      Stream<InvitationAcceptanceState> states = const Stream.empty(),
      FuzzzySkin skin = FuzzzySkin.night,
    }) async {
      whenListen(
        cubit,
        states,
        initialState:
            const InvitationAcceptanceState(status: StateStatus.initial),
      );
      await pumpPeople(
        tester,
        BlocProvider<InvitationAcceptanceCubit>.value(
          value: cubit,
          child: ProvidedInvitationAcceptancePage(
            prefillInvitationContent: prefill,
          ),
        ),
        skin: skin,
      );
    }

    for (final skin in redesignSkins) {
      testWidgets(
          'step 1 of 3: Paste it, Choose a file, links open by themselves '
          '($skin)', (tester) async {
        await pumpGot(tester, skin: skin);
        expect(find.text('STEP 1 OF 3 · OPEN IT'), findsOneWidget);
        expect(find.text('Open the invite'), findsOneWidget);
        expect(find.text('Paste it'), findsOneWidget);
        expect(find.text('Choose a file'), findsOneWidget);
        expect(
          find.text(
            'Links and QR codes come here. Nothing opens until you tap Open.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'a pasted invite is read, then "The invite is good. Who sent it?" '
        'and Accept', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': '  $_invite '}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pumpGot(tester);
      await tester.tap(find.text('Paste it'));
      await tester.pumpAndSettle();

      verify(() => cubit.checkInvitation(_invite)).called(1);
      expect(find.text('STEP 2 OF 3 · NAME'), findsOneWidget);
      expect(find.text('The invite is good.'), findsOneWidget);
      expect(find.text('Who sent it?'), findsOneWidget);
      final accept = find.byKey(const Key('btn.gotInvite.accept'));
      expect(_button(tester, accept).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Tamar');
      await tester.pump();
      await tester.tap(accept);
      verify(
        () => cubit.acceptInvitation(
          invitationContent: _invite,
          chatName: 'Tamar',
        ),
      ).called(1);
    });

    testWidgets('a tapped invite link skips step 1', (tester) async {
      await pumpGot(tester, prefill: _invite);
      await tester.pumpAndSettle();
      expect(find.text('Who sent it?'), findsOneWidget);
    });

    for (final (check, title) in [
      (InvitationCheck.ownInvitation, "That's your own invite."),
      (InvitationCheck.alreadyConnected, "You're already connected."),
      (InvitationCheck.damaged, "Can't open this."),
    ]) {
      testWidgets('$check stays on step 1 with one fact', (tester) async {
        when(() => cubit.checkInvitation(any())).thenAnswer((_) async => check);
        await pumpGot(tester, prefill: _invite);
        await tester.pumpAndSettle();
        expect(find.textContaining(title), findsOneWidget);
        expect(find.text('Open the invite'), findsOneWidget);
      });
    }

    testWidgets('accepted: on to "Send your reply"', (tester) async {
      await pumpGot(
        tester,
        prefill: _invite,
        states: Stream.value(
          InvitationAcceptanceState(
            status: StateStatus.success,
            chatData: _tamar,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('to /chat/acceptance-export Tamar'), findsOneWidget);
    });
  });

  group('Send your reply', () {
    late MockAcceptanceReaderCubit reader;

    setUp(() {
      reader = MockAcceptanceReaderCubit();
      whenListen(
        reader,
        const Stream<AcceptanceReaderState>.empty(),
        initialState: const AcceptanceReaderState(
          status: StateStatus.success,
          acceptance:
              CryptoCoreAcceptance(chatId: peopleChatId, content: _reply),
        ),
      );
    });

    for (final skin in redesignSkins) {
      testWidgets(
          'step 3 of 3: the same way the invite came, Share reply, check '
          'numbers next; Done opens Tamar ($skin)', (tester) async {
        await pumpPeople(
          tester,
          BlocProvider<AcceptanceReaderCubit>.value(
            value: reader,
            child: ProvidedAcceptanceExportPage(
              payload: AcceptanceExportPagePayload(
                chatGeneralData: _tamar,
                hasBackButton: false,
              ),
            ),
          ),
          skin: skin,
        );
        expect(find.text('STEP 3 OF 3 · REPLY'), findsOneWidget);
        expect(find.text('Send your reply to Tamar'), findsOneWidget);
        expect(find.text('The same way the invite came.'), findsOneWidget);
        expect(find.byKey(const Key('steps_picture.reply')), findsOneWidget);
        expect(find.text('Share reply'), findsOneWidget);
        expect(find.text('Then check numbers together.'), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn.reply.done')));
        await tester.pumpAndSettle();
        expect(find.text('to /person?chat=$peopleChatId'), findsOneWidget);
      });
    }
  });

  group('Connected with Tamar', () {
    for (final skin in redesignSkins) {
      testWidgets(
          'the steps complete, the check draws, one medium buzz; Is it '
          'really Tamar? ($skin)', (tester) async {
        final haptics = recordHaptics(tester);
        await pumpPeople(
          tester,
          PersonConnectedPage(chat: _tamar),
          skin: skin,
        );
        await tester.pumpAndSettle();
        expect(find.text('Connected with Tamar'), findsOneWidget);
        expect(find.byKey(const Key('hero.connected')), findsOneWidget);
        expect(find.byKey(const Key('steps_picture.connected')), findsOne);
        expect(find.text('Is it really Tamar?'), findsOneWidget);
        expect(find.text('Check numbers together.'), findsOneWidget);
        expect(haptics, ['HapticFeedbackType.mediumImpact']);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Check now opens the numbers; Later opens Tamar',
        (tester) async {
      await pumpPeople(tester, PersonConnectedPage(chat: _tamar));
      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();
      expect(find.text('to /chat/verify Tamar'), findsOneWidget);

      await pumpPeople(tester, PersonConnectedPage(chat: _tamar));
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('to /person?chat=$peopleChatId'), findsOneWidget);
    });

    testWidgets('with Fuzzzy Cast on, Fuzzz is happy instead of the check',
        (tester) async {
      await pumpPeople(tester, PersonConnectedPage(chat: _tamar), castOn: true);
      expect(find.byType(CastFigure), findsOneWidget);
      expect(find.byKey(const Key('hero.connected')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Someone else may have answered', () {
    for (final skin in redesignSkins) {
      testWidgets(
          'the red note, Check numbers, Remove and invite again; never '
          'Fuzzz ($skin)', (tester) async {
        await pumpPeople(
          tester,
          AnsweredTwicePage(chat: _tamar),
          skin: skin,
          castOn: true,
        );
        expect(find.text('Someone else may have answered'), findsOneWidget);
        expect(
          find.text('Your invite to Tamar got two replies.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('notice.answeredTwice')), findsOneWidget);
        expect(find.byType(CastFigure), findsNothing);
        expect(find.text('Remove Tamar, invite again'), findsOneWidget);

        await tester.tap(find.text('Check numbers'));
        await tester.pumpAndSettle();
        expect(find.text('to /chat/verify Tamar'), findsOneWidget);
      });
    }

    testWidgets('Remove, invite again: removes, then a new invite for Tamar',
        (tester) async {
      final list = chatListOf([_tamar]);
      when(() => list.deleteChat(chatId: peopleChatId))
          .thenAnswer((_) async {});
      await pumpPeople(tester, AnsweredTwicePage(chat: _tamar), chatList: list);
      await tester.tap(find.text('Remove Tamar, invite again'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn.removePerson.confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      verify(() => list.deleteChat(chatId: peopleChatId)).called(1);
      expect(find.text('to /chat/create Tamar'), findsOneWidget);
    });
  });

  group("It's really Tamar", () {
    for (final skin in redesignSkins) {
      testWidgets('the check draws, the Checked chip rises, Done ($skin)',
          (tester) async {
        final haptics = recordHaptics(tester);
        await pumpPeople(tester, PersonCheckedPage(chat: _tamar), skin: skin);
        await tester.pumpAndSettle();
        expect(find.text("It's really Tamar"), findsOneWidget);
        expect(find.text('CHECKED'), findsOneWidget);
        expect(haptics, ['HapticFeedbackType.mediumImpact']);

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(
          find.text('to /person?chat=$peopleChatId&checked=1'),
          findsOneWidget,
        );
      });
    }
  });
}
