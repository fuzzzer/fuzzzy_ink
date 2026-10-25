import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

import '../../../../helpers/redesign_harness.dart';

void main() {
  group('RecoveryKeyBlock', () {
    test('finds the groups however the key is written', () {
      expect(
        RecoveryKeyBlock.groupsOf('K7QF 3MZD 8WTR PX2N LC5H 9VBA T4EJ 6YRU'),
        hasLength(8),
      );
      expect(RecoveryKeyBlock.groupsOf('K7QF-3MZD-8WTR-PX2N'), hasLength(4));
      expect(
        RecoveryKeyBlock.groupsOf('K7QF3MZD8WTR'),
        ['K7QF', '3MZD', '8WTR'],
      );
    });

    for (final skin in redesignSkins) {
      testWidgets(
          'two lines of four groups, not selectable, with its tag '
          '($skin)', (tester) async {
        await pumpRedesign(
          tester,
          RecoveryKeyBlock(
            qaId: 'setup',
            recoveryKey: 'K7QF 3MZD 8WTR PX2N LC5H 9VBA T4EJ 6YRU',
            actions: TextButton(onPressed: () {}, child: const Text('Print')),
          ),
          skin: skin,
          private: true,
          surface: const Size(320, 640),
        );
        expect(find.text('K7QF 3MZD 8WTR PX2N'), findsOneWidget);
        expect(find.text('LC5H 9VBA T4EJ 6YRU'), findsOneWidget);
        expect(find.text('NO COPY · NO SCREENSHOTS'), findsOneWidget);
        expect(find.text('Print'), findsOneWidget);
        expect(find.byType(SelectableText), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('LockoutCountdownBar', () {
    double widthFactor(WidgetTester tester) => tester
        .widget<FractionallySizedBox>(
          find.descendant(
            of: find.byKey(const Key('lockout.bar')),
            matching: find.byType(FractionallySizedBox),
          ),
        )
        .widthFactor!;

    for (final skin in redesignSkins) {
      testWidgets('full when the wait begins, empty when it ends ($skin)',
          (tester) async {
        await pumpRedesign(
          tester,
          const LockoutCountdownBar(remaining: Duration(seconds: 30)),
          skin: skin,
        );
        expect(widthFactor(tester), 1);

        await tester.pump(const Duration(seconds: 15));
        expect(widthFactor(tester), closeTo(0.5, 0.02));

        // The auth store's next tick resynchronises the bar to the truth.
        await pumpRedesign(
          tester,
          const LockoutCountdownBar(remaining: Duration(seconds: 14)),
          skin: skin,
        );
        expect(widthFactor(tester), closeTo(14 / 30, 0.01));

        await pumpRedesign(
          tester,
          const LockoutCountdownBar(remaining: Duration.zero),
          skin: skin,
        );
        expect(find.byKey(const Key('lockout.bar')), findsNothing);
      });
    }

    testWidgets('no bar with reduced motion: the countdown text says it',
        (tester) async {
      await pumpRedesign(
        tester,
        const LockoutCountdownBar(remaining: Duration(seconds: 30)),
        reduceMotion: true,
      );
      expect(find.byKey(const Key('lockout.bar')), findsNothing);
    });

    testWidgets('stays on the private lock screen (it is an in-place change)',
        (tester) async {
      await pumpRedesign(
        tester,
        const LockoutCountdownBar(remaining: Duration(seconds: 30)),
        private: true,
      );
      expect(find.byKey(const Key('lockout.bar')), findsOneWidget);
    });
  });
}
