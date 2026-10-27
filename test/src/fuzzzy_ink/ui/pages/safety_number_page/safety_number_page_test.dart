import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/people_harness.dart';
import '../../../../../helpers/redesign_harness.dart';

const _digits = '12345 67890 11111 22222 33333 44444 '
    '55555 66666 77777 88888 99999 00000';

/// "Is it really Alice?": the numbers, the version that made them (two
/// builds that compute them differently never show silently different
/// digits), and what Same numbers, Different numbers and Mark as not checked
/// do.
void main() {
  late MockSafetyNumberCubit cubit;
  final alice = personChat(name: 'Alice');

  setUp(() {
    cubit = MockSafetyNumberCubit();
    when(() => cubit.toggleVerified()).thenAnswer((_) async {});
  });

  Future<MockChatGeneralDataListCubit> pumpSafety(
    WidgetTester tester, {
    bool isVerified = false,
    FuzzzySkin skin = FuzzzySkin.night,
    SafetyNumberState? state,
  }) async {
    whenListen(
      cubit,
      const Stream<SafetyNumberState>.empty(),
      initialState: state ??
          SafetyNumberState(
            status: StateStatus.success,
            safetyNumber: const SafetyNumber(version: 7, digits: _digits),
            isVerified: isVerified,
          ),
    );
    final list = chatListOf([alice]);
    when(list.refreshVerification).thenAnswer((_) async {});
    when(() => list.deleteChat(chatId: any(named: 'chatId')))
        .thenAnswer((_) async {});
    await pumpPeople(
      tester,
      BlocProvider<SafetyNumberCubit>.value(
        value: cubit,
        child: ProvidedSafetyNumberPage(chatGeneralData: alice),
      ),
      chatList: list,
      skin: skin,
    );
    return list;
  }

  for (final skin in redesignSkins) {
    testWidgets(
        'shows the 12 groups together with the version that made them, '
        'and Same / Different numbers ($skin)', (tester) async {
      await pumpSafety(tester, skin: skin);

      expect(find.text('Is it really Alice?'), findsOneWidget);
      expect(find.text('Compare on a call, or side by side.'), findsOneWidget);
      for (final group in _digits.split(' ')) {
        expect(find.text(group), findsOneWidget);
      }
      final en = FuzzzyInkLocalizationsEn();
      expect(find.text(en.safetyNumberVersion(7)), findsOneWidget);
      expect(find.text('Same numbers'), findsOneWidget);
      expect(find.text('Different numbers'), findsOneWidget);
      expect(find.text('Mark as not checked'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'Same numbers saves Checked, refreshes trust, then "It\'s '
      'really Alice"', (tester) async {
    final list = await pumpSafety(tester);
    await tester.tap(find.text('Same numbers'));
    await tester.pumpAndSettle();

    verify(() => cubit.toggleVerified()).called(1);
    verify(list.refreshVerification).called(1);
    expect(find.text('to /person/checked Alice'), findsOneWidget);
  });

  testWidgets('a mark the core refuses says so and stays', (tester) async {
    final list = await pumpSafety(tester);
    when(() => cubit.state).thenReturn(
      const SafetyNumberState(
        status: StateStatus.failed,
        safetyNumber: SafetyNumber(version: 7, digits: _digits),
      ),
    );
    await tester.tap(find.text('Same numbers'));
    await tester.pump();
    await tester.pump();
    verifyNever(list.refreshVerification);
    expect(find.text("Couldn't save that. Try again."), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('Different numbers: the red sheet, then Remove asks first',
      (tester) async {
    final list = await pumpSafety(tester);
    await tester.tap(find.text('Different numbers'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notice.mismatch')), findsOneWidget);
    expect(find.textContaining("Don't send Alice anything."), findsOneWidget);
    expect(find.textContaining('Someone may be in between.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn.mismatch.remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove Alice?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn.removePerson.confirm')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    verify(() => list.deleteChat(chatId: peopleChatId)).called(1);
    expect(find.text('to /'), findsOneWidget);
  });

  testWidgets('checked before: says so, and Mark as not checked',
      (tester) async {
    final list = await pumpSafety(tester, isVerified: true);
    expect(find.text('You checked Alice before.'), findsOneWidget);
    expect(find.byKey(const Key('notice.safety.checkedBefore')), findsOne);
    expect(find.text('Same numbers'), findsNothing);

    await tester.tap(find.text('Mark as not checked'));
    await tester.pump();
    await tester.pump();
    verify(() => cubit.toggleVerified()).called(1);
    verify(list.refreshVerification).called(1);
    expect(find.text('Alice is now Not checked.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('numbers that cannot be read say so', (tester) async {
    await pumpSafety(
      tester,
      state: const SafetyNumberState(status: StateStatus.failed),
    );
    expect(find.byKey(const Key('notice.safety.failed')), findsOneWidget);
  });
}
