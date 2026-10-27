import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/people_harness.dart';

final _now = DateTime(2026, 10, 26, 12);

MessageData _row(
  int id, {
  required bool isSent,
  required DateTime at,
  MessageType type = MessageType.text,
  String text = 'the keys are under the blue pot',
}) =>
    MessageData(
      id: id,
      chatId: peopleChatId,
      type: type,
      encryptedMessage: type.isFile ? 'files/lease-$id.pdf.fuzz' : 'AwEC$id',
      decryptedMessage: type.isFile ? 'files/lease-$id.pdf.fuzz' : text,
      sentAt: at,
      isSent: isSent,
    );

final _history = [
  _row(4, isSent: true, at: DateTime(2026, 10, 26, 9, 20)),
  _row(3, isSent: false, at: DateTime(2026, 10, 26, 8), type: MessageType.file),
  _row(2, isSent: false, at: DateTime(2026, 10, 25, 18, 5)),
  _row(1, isSent: true, at: DateTime(2026, 10, 20, 7), type: MessageType.file),
];

void main() {
  late MockConnectedChatCubit history;

  setUp(() {
    HistoryFormat.now = () => _now;
    history = MockConnectedChatCubit();
    when(() => history.reloadMessages()).thenAnswer((_) async {});
    when(() => history.loadOlderMessages()).thenAnswer((_) async {});
  });

  tearDown(() => HistoryFormat.now = DateTime.now);

  void showHistory(List<MessageData> rows, {StateStatus? status}) {
    whenListen(
      history,
      const Stream<ConnectedChatState>.empty(),
      initialState: ConnectedChatState(
        status: status ?? StateStatus.success,
        messages: rows,
        hasFetchedAllMessages: true,
      ),
    );
  }

  Future<void> pumpPerson(
    WidgetTester tester, {
    ChatGeneralData? chat,
    Set<String> unverified = const {},
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
    int? newMessageId,
    bool justChecked = false,
    List<String> extraStubs = const [],
    MockChatGeneralDataListCubit? list,
    double textScale = 1,
    Locale locale = const Locale('en'),
  }) async {
    final person = chat ?? personChat();
    await pumpPeople(
      tester,
      BlocProvider<ConnectedChatCubit>.value(
        value: history,
        child: ProvidedPersonPage(
          chatId: person.chatId,
          newMessageId: newMessageId,
          justChecked: justChecked,
          fileSizeOf: (_) async => 3250000,
        ),
      ),
      chatList: list ?? chatListOf([person], unverified: unverified),
      skin: skin,
      reduceMotion: reduceMotion,
      extraStubs: extraStubs,
      textScale: textScale,
      locale: locale,
    );
    await tester.pump();
  }

  group('connected', () {
    for (final skin in redesignSkinsForPeople) {
      for (final reduced in [false, true]) {
        testWidgets(
            'not checked: the banner, Lock and Open, the filter, rows by '
            'day that never show the text ($skin, reduced motion $reduced)',
            (tester) async {
          showHistory(_history);
          await pumpPerson(
            tester,
            unverified: {peopleChatId},
            skin: skin,
            reduceMotion: reduced,
          );
          await tester.pumpAndSettle();

          expect(find.text('Nino'), findsOneWidget);
          // Private: names, times and file names (security review
          // 2026-10-26).
          expect(
            SensitiveScreen.isIn(tester.element(find.text('Nino'))),
            isTrue,
          );
          expect(find.byKey(const Key('notice.person.notChecked')), findsOne);
          expect(find.byKey(const Key('btn.person.lock')), findsOneWidget);
          expect(find.byKey(const Key('btn.person.open')), findsOneWidget);
          expect(find.byKey(const Key('seg.person.filter')), findsOneWidget);
          expect(find.text('TODAY'), findsOneWidget);
          expect(find.text('YESTERDAY'), findsOneWidget);
          expect(find.byType(HistoryRow), findsNWidgets(4));
          expect(find.text('You locked a message'), findsOneWidget);
          expect(find.text('You opened a message'), findsOneWidget);
          expect(find.text('You opened lease-3.pdf'), findsOneWidget);
          expect(find.textContaining('3.1 MB'), findsWidgets);
          expect(find.text('09:20'), findsOneWidget);
          expect(find.textContaining('blue pot'), findsNothing);
          await tester.scrollUntilVisible(
            find.byKey(const Key('person.footer')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            find.text('History stays locked on this phone.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('checked: the chip instead of the banner', (tester) async {
      showHistory(_history);
      await pumpPerson(tester);
      expect(find.byKey(const Key('notice.person.notChecked')), findsNothing);
      expect(find.text('CHECKED'), findsOneWidget);
    });

    testWidgets(
        'coming from "Checked": the banner gives way to the chip in place',
        (tester) async {
      showHistory(_history);
      await pumpPerson(tester, justChecked: true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notice.person.notChecked')), findsNothing);
      expect(find.text('CHECKED'), findsOneWidget);
    });

    testWidgets('the filter shows locked or opened rows only', (tester) async {
      showHistory(_history);
      await pumpPerson(tester);

      await tester.tap(find.text('Locked'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryRow), findsNWidgets(2));
      expect(find.text('You opened a message'), findsNothing);

      await tester.tap(find.text('Opened'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryRow), findsNWidgets(2));
      expect(find.text('You locked a message'), findsNothing);
    });

    for (final locale in [const Locale('en'), const Locale('ka')]) {
      testWidgets(
          'the largest text: the filter shrinks to fit, no overflow, and a '
          'tap still picks the segment drawn (${locale.languageCode})',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        showHistory(_history);
        await pumpPerson(tester, textScale: 3.1, locale: locale);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final filter = find.byKey(const Key('seg.person.filter'));
        expect(tester.getRect(filter).right, lessThanOrEqualTo(320));
        final opened = find.bySemanticsIdentifier('seg.person.filter.2');
        await tester.tap(opened);
        await tester.pumpAndSettle();
        expect(
          find.text('You locked a message', skipOffstage: false),
          findsNothing,
        );
      });
    }

    testWidgets('empty history, and an empty filter', (tester) async {
      showHistory([_history.first]);
      await pumpPerson(tester);
      await tester.tap(find.text('Opened'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing opened yet.'), findsOneWidget);

      showHistory(const []);
      await pumpPerson(tester);
      expect(find.text('Nothing here yet.'), findsOneWidget);
    });

    testWidgets('loading shows skeleton rows', (tester) async {
      showHistory(const [], status: StateStatus.loading);
      await pumpPerson(tester);
      expect(find.byKey(const Key('person.loading')), findsOneWidget);
    });

    testWidgets('a load error says so and tries again', (tester) async {
      when(() => history.loadCurrentMessagesPage()).thenAnswer((_) async {});
      showHistory(const [], status: StateStatus.failed);
      await pumpPerson(tester);
      expect(find.text("Couldn't load the history."), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn.person.retry')));
      verify(() => history.loadCurrentMessagesPage()).called(1);
    });

    testWidgets('the row just added glows once', (tester) async {
      showHistory(_history);
      await pumpPerson(tester, newMessageId: 4);
      final tint = tester.widget<RowTint>(
        find.ancestor(
          of: find.byKey(const Key('history.4')),
          matching: find.byType(RowTint),
        ),
      );
      expect(tint.play, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('a row opens its item; the banner opens the numbers',
        (tester) async {
      showHistory(_history);
      await pumpPerson(tester, unverified: {peopleChatId});

      await tester.tap(find.byKey(const Key('history.4')));
      await tester.pumpAndSettle();
      expect(find.text('to /person/item item 4'), findsOneWidget);
    });

    testWidgets('the "Not checked yet" banner opens "Is it really Nino?"',
        (tester) async {
      showHistory(_history);
      await pumpPerson(tester, unverified: {peopleChatId});
      await tester.tap(find.byKey(const Key('notice.person.notChecked')));
      await tester.pumpAndSettle();
      expect(find.text('to /chat/verify Nino'), findsOneWidget);
    });

    testWidgets(
        'Lock and Open go to their screens and come back here, and the '
        'history is read again on the way back', (tester) async {
      showHistory(_history);
      await pumpPerson(
        tester,
        extraStubs: [AppRouter.lockFor, AppRouter.open],
      );

      await tester.tap(find.byKey(const Key('btn.person.open')));
      await tester.pumpAndSettle();
      expect(find.text('to /open back'), findsOneWidget);
      Navigator.of(tester.element(find.textContaining('to /open'))).pop();
      await tester.pumpAndSettle();
      verify(() => history.reloadMessages()).called(1);

      await tester.tap(find.byKey(const Key('btn.person.lock')));
      await tester.pumpAndSettle();
      expect(find.text('to /lock/for Nino back'), findsOneWidget);
    });

    testWidgets('the row Lock or Open wrote glows once on the way back',
        (tester) async {
      showHistory(_history);
      await pumpPerson(tester, extraStubs: [AppRouter.lockFor]);
      await tester.tap(find.byKey(const Key('btn.person.lock')));
      await tester.pumpAndSettle();
      RecentHistoryRow.mark(chatId: peopleChatId, messageId: _history.first.id);
      Navigator.of(tester.element(find.textContaining('to /lock/for'))).pop();
      await tester.pumpAndSettle();
      final row = tester.widget<HistoryRow>(
        find.byKey(ValueKey(_history.first.id)),
      );
      expect(row.highlight, isTrue);
      expect(RecentHistoryRow.take(peopleChatId), isNull);
    });
  });

  group('waiting', () {
    for (final skin in redesignSkinsForPeople) {
      testWidgets(
          'the waiting card: steps, the two notes, Share invite again and '
          'I got the reply ($skin)', (tester) async {
        showHistory(const []);
        await pumpPerson(
          tester,
          chat: personChat(name: 'Mom', status: ChatSetupStatus.invited),
          skin: skin,
        );
        expect(find.text("Waiting for Mom's reply"), findsOneWidget);
        expect(
          find.byKey(const Key('steps_picture.person.waiting')),
          findsOneWidget,
        );
        expect(
          find.text('Once Mom replies, you can lock messages for each other.'),
          findsOneWidget,
        );
        expect(
          find.text('Send the invite any way, even publicly. It stays safe.'),
          findsOneWidget,
        );
        expect(find.text('Share invite again'), findsOneWidget);
        expect(find.text('I got the reply'), findsOneWidget);
        expect(find.byKey(const Key('btn.person.lock')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('I got the reply opens "Open the reply"', (tester) async {
      showHistory(const []);
      await pumpPerson(
        tester,
        chat: personChat(name: 'Mom', status: ChatSetupStatus.invited),
      );
      await tester.tap(find.text('I got the reply'));
      await tester.pumpAndSettle();
      expect(find.text('Open the reply'), findsOneWidget);
      expect(find.text('Paste it'), findsOneWidget);
      expect(find.text('Choose a file'), findsOneWidget);
    });
  });

  group('More', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('iconbtn.person.more')));
      await tester.pumpAndSettle();
    }

    testWidgets('connected: Check numbers, Save history, Remove',
        (tester) async {
      showHistory(_history);
      await pumpPerson(tester, unverified: {peopleChatId});
      await openMenu(tester);
      expect(find.text('Check numbers'), findsOneWidget);
      expect(find.text('Not checked yet'), findsOneWidget);
      expect(find.text('Save history as a file'), findsOneWidget);
      expect(find.text('Remove Nino'), findsOneWidget);
      expect(find.text('Send my reply again'), findsNothing);
      expect(find.text('Share invite again'), findsNothing);

      await tester.tap(find.text('Check numbers'));
      await tester.pumpAndSettle();
      expect(find.text('to /chat/verify Nino'), findsOneWidget);
    });

    testWidgets('they invited you: Send my reply again', (tester) async {
      showHistory(_history);
      await pumpPerson(tester, chat: personChat(didAcceptInvitation: true));
      await openMenu(tester);
      expect(find.text('Send my reply again'), findsOneWidget);
    });

    testWidgets('waiting: Share invite again and Remove only', (tester) async {
      showHistory(const []);
      await pumpPerson(
        tester,
        chat: personChat(name: 'Mom', status: ChatSetupStatus.invited),
      );
      await openMenu(tester);
      expect(find.text('Share invite again'), findsNWidgets(2));
      expect(find.text('Remove Mom'), findsOneWidget);
      expect(find.text('Check numbers'), findsNothing);
      expect(find.text('Save history as a file'), findsNothing);
    });

    testWidgets(
        'Remove asks first, then removes Nino and goes Home with a message',
        (tester) async {
      showHistory(_history);
      final list = chatListOf([personChat()]);
      when(() => list.deleteChat(chatId: peopleChatId))
          .thenAnswer((_) async {});
      await pumpPerson(tester, list: list);
      await openMenu(tester);
      await tester.tap(find.text('Remove Nino'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Nino?'), findsOneWidget);
      expect(
        find.text('Their history and files leave this phone. No undo.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('btn.removePerson.cancel')));
      await tester.pumpAndSettle();
      verifyNever(() => list.deleteChat(chatId: any(named: 'chatId')));

      await openMenu(tester);
      await tester.tap(find.text('Remove Nino'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn.removePerson.confirm')));
      await tester.pump();
      await tester.pump();
      verify(() => list.deleteChat(chatId: peopleChatId)).called(1);
      expect(find.text('Nino was removed.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('to /'), findsOneWidget);
    });
  });

  test('the location carries the chat id and the new row', () {
    expect(
      PersonPage.location(peopleChatId, newMessageId: 7),
      '/person?chat=$peopleChatId&new=7',
    );
  });
}

/// Both looks the redesign ships.
const redesignSkinsForPeople = [FuzzzySkin.paper, FuzzzySkin.night];
