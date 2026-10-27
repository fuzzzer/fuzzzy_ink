import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

import '../../../../helpers/redesign_harness.dart';

double _checkProgress(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(CheckDraw),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CheckPainter,
      ),
    ),
  );
  return (paint.painter! as CheckPainter).progress;
}

void main() {
  group('CheckDraw', () {
    for (final skin in redesignSkins) {
      testWidgets('draws itself once over the standard time ($skin)',
          (tester) async {
        await pumpRedesign(tester, const CheckDraw(), skin: skin);
        expect(_checkProgress(tester), 0);

        await tester.pump(const Duration(milliseconds: 110));
        final halfway = _checkProgress(tester);
        expect(halfway, greaterThan(0));
        expect(halfway, lessThan(1));

        await tester.pumpAndSettle();
        expect(_checkProgress(tester), 1);
      });

      testWidgets('is simply there with reduced motion ($skin)',
          (tester) async {
        await pumpRedesign(
          tester,
          const CheckDraw(),
          skin: skin,
          reduceMotion: true,
        );
        expect(_checkProgress(tester), 1);
      });
    }

    testWidgets('waits for its delay before drawing', (tester) async {
      await pumpRedesign(
        tester,
        const CheckDraw(delay: InkMotionTiming.checkDelay),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(_checkProgress(tester), 0);
      await tester.pumpAndSettle();
      expect(_checkProgress(tester), 1);
    });
  });

  group('InPlaceConfirmButton', () {
    Widget button(Future<bool> Function() action) => Center(
          child: InPlaceConfirmButton(
            label: 'Copy locked text',
            confirmedLabel: 'Copied',
            qaId: 'copy',
            onPressed: action,
          ),
        );

    for (final skin in redesignSkins) {
      for (final reduced in [false, true]) {
        testWidgets(
            'confirms only after the real result, keeps its size, then '
            'returns ($skin, reduced motion $reduced)', (tester) async {
          final haptics = recordHaptics(tester);
          await pumpRedesign(
            tester,
            button(() async => true),
            skin: skin,
            reduceMotion: reduced,
          );
          final before = tester.getSize(find.byType(InPlaceConfirmButton));

          await tester.tap(find.text('Copy locked text'));
          await tester.pump();
          expect(find.text('Copied'), findsOneWidget);
          expect(find.byType(CheckDraw), findsOneWidget);
          expect(tester.getSize(find.byType(InPlaceConfirmButton)), before);
          expect(haptics, ['HapticFeedbackType.lightImpact']);

          await tester.pump(InkMotionTiming.confirmHold);
          await tester.pumpAndSettle();
          // The confirmed face is gone from what is shown.
          final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
          expect(stack.index, 0);
        });
      }
    }

    testWidgets('a refused action changes nothing', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpRedesign(tester, button(() async => false));
      await tester.tap(find.text('Copy locked text'));
      await tester.pumpAndSettle();
      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 0);
      expect(haptics, isEmpty);
    });

    testWidgets('a second press restarts the confirmation', (tester) async {
      await pumpRedesign(tester, button(() async => true));
      await tester.tap(find.text('Copy locked text'));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.tap(find.text('Copied'));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        1,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        0,
      );
    });
  });

  group('RowTint', () {
    const row = RowTint(play: true, child: SizedBox(height: 64));

    for (final skin in redesignSkins) {
      testWidgets('glows once and fades out over 1.6 s ($skin)',
          (tester) async {
        await pumpRedesign(tester, row, skin: skin);
        await tester.pump();
        expect(find.byKey(const Key('row_tint.active')), findsOneWidget);
        await tester.pump(InkMotionTiming.rowTint);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('row_tint.active')), findsNothing);
      });
    }

    testWidgets('nothing with reduced motion', (tester) async {
      await pumpRedesign(tester, row, reduceMotion: true);
      await tester.pump();
      expect(find.byKey(const Key('row_tint.active')), findsNothing);
    });

    testWidgets('nothing on a private screen', (tester) async {
      await pumpRedesign(tester, row, private: true);
      await tester.pump();
      expect(find.byKey(const Key('row_tint.active')), findsNothing);
    });
  });

  group('ChipSwap', () {
    Widget chip(String label) => ChipSwap(
          child: FuzzzyStatusChip(
            key: ValueKey(label),
            label: label,
            kind: FuzzzyStatusKind.success,
          ),
        );

    testWidgets('the new chip rises into place where the old one was',
        (tester) async {
      await pumpRedesign(tester, chip('Not checked'));
      await pumpRedesign(tester, chip('Checked'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const ValueKey('Not checked')), findsOneWidget);
      expect(find.byKey(const ValueKey('Checked')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('Not checked')), findsNothing);
      expect(find.byKey(const ValueKey('Checked')), findsOneWidget);
    });

    testWidgets('swaps at once with reduced motion', (tester) async {
      await pumpRedesign(tester, chip('Not checked'), reduceMotion: true);
      await pumpRedesign(tester, chip('Checked'), reduceMotion: true);
      await tester.pump();
      expect(find.byKey(const ValueKey('Not checked')), findsNothing);
      expect(find.byKey(const ValueKey('Checked')), findsOneWidget);
    });
  });

  group('LiftIn and SettleIn', () {
    double offsetY(WidgetTester tester) {
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(LiftIn),
              matching: find.byType(Transform),
            )
            .first,
      );
      return transform.transform.getTranslation().y;
    }

    testWidgets('the app lifts 14 px into place after an unlock',
        (tester) async {
      await pumpRedesign(tester, const LiftIn(child: Text('Home')));
      expect(offsetY(tester), closeTo(14, 0.01));
      await tester.pumpAndSettle();
      expect(offsetY(tester), 0);
    });

    testWidgets('no lift with reduced motion or on a private screen',
        (tester) async {
      await pumpRedesign(
        tester,
        const LiftIn(child: Text('Home')),
        reduceMotion: true,
      );
      expect(offsetY(tester), 0);
      await pumpRedesign(
        tester,
        const LiftIn(child: Text('Lock')),
        private: true,
      );
      expect(offsetY(tester), 0);
    });

    testWidgets('a mark settles from 0.9, also on a private screen',
        (tester) async {
      await pumpRedesign(
        tester,
        const SettleIn(child: InkMark(size: 56)),
        private: true,
      );
      final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(SettleIn),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, closeTo(0.9, 0.001));
      await tester.pumpAndSettle();
      expect(scale.scale.value, 1);
    });
  });

  group('hero glyphs', () {
    for (final skin in redesignSkins) {
      for (final reduced in [false, true]) {
        testWidgets(
            'lock done: the lock snaps shut with one medium buzz '
            '($skin, reduced motion $reduced)', (tester) async {
          final haptics = recordHaptics(tester);
          await pumpRedesign(
            tester,
            const Center(child: LockSnapGlyph(qaId: 'locked')),
            skin: skin,
            reduceMotion: reduced,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('hero.locked')), findsOneWidget);
          expect(haptics, ['HapticFeedbackType.mediumImpact']);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('every tone draws, the check draws itself ($skin)',
          (tester) async {
        await pumpRedesign(
          tester,
          const Column(
            children: [
              HeroGlyph(icon: Icons.people_outline),
              HeroGlyph(icon: Icons.ios_share, tone: HeroGlyphTone.inverted),
              HeroGlyph(icon: Icons.warning_amber, tone: HeroGlyphTone.warning),
              HeroGlyph(drawCheck: true, settle: true),
            ],
          ),
          skin: skin,
        );
        await tester.pumpAndSettle();
        expect(find.byType(CheckDraw), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('haptics are silent off phones', () async {
    InkHaptics.debugIsPhone = false;
    addTearDown(() => InkHaptics.debugIsPhone = null);
    // Completes without reaching a platform channel.
    await InkHaptics.light();
    await InkHaptics.medium();
    await InkHaptics.heavy();
    await InkHaptics.selection();
  });
}
