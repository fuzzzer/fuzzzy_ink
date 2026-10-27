import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_cast/fuzzzy_cast.dart';
import 'package:fuzzzy_ink/src/src.dart';

import '../../../../helpers/redesign_harness.dart';

/// A screen with its keeper's two spots, far apart.
Widget _screen({bool enabled = true}) => CastKeeper(
      character: CastCharacters.fuzzz,
      tabPath: AppRouter.home,
      qaId: 'test',
      enabled: enabled,
      child: const Column(
        children: [
          Row(
            children: [Expanded(child: Text('title')), CastKeeperSpot(0)],
          ),
          SizedBox(height: 200),
          Row(
            children: [Expanded(child: Text('label')), CastKeeperSpot(1)],
          ),
        ],
      ),
    );

const _keeper = Key('keeper.test');

double _keeperTop(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(_keeper)).dy;

/// Hidden, a short pause, back in the other spot.
Future<void> _hopped(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

CastFigure _figure(WidgetTester tester) =>
    tester.widget<CastFigure>(find.byType(CastFigure));

void main() {
  setUp(CastKeeperCues.reset);
  tearDown(CastKeeperCues.reset);

  testWidgets('nothing, and no room taken, while Fuzzzy Cast is off',
      (tester) async {
    await pumpRedesign(tester, _screen());
    await tester.pumpAndSettle();
    expect(find.byKey(_keeper), findsNothing);
    expect(tester.getSize(find.byType(CastKeeperSpot).first), Size.zero);
  });

  testWidgets('never below a private screen, nor while not enabled',
      (tester) async {
    await pumpRedesign(tester, _screen(), castOn: true, private: true);
    await tester.pumpAndSettle();
    expect(find.byKey(_keeper), findsNothing);

    await pumpRedesign(tester, _screen(enabled: false), castOn: true);
    await tester.pumpAndSettle();
    expect(find.byKey(_keeper), findsNothing);
  });

  testWidgets('sits in its first spot; a tap moves it to the other one',
      (tester) async {
    await pumpRedesign(tester, _screen(), castOn: true);
    await tester.pumpAndSettle();
    final first = _keeperTop(tester);
    expect(_figure(tester).character, CastCharacters.fuzzz);

    await tester.tap(find.byKey(_keeper));
    await _hopped(tester);
    expect(_keeperTop(tester), greaterThan(first + 150));

    await tester.tap(find.byKey(_keeper));
    await _hopped(tester);
    expect(_keeperTop(tester), first);
  });

  testWidgets('screen readers skip it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRedesign(tester, _screen(), castOn: true);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ExcludeSemantics),
        matching: find.byKey(_keeper),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('after a lock: a short happy move, then rest', (tester) async {
    await pumpRedesign(tester, _screen(), castOn: true);
    await tester.pumpAndSettle();
    CastKeeperCues.cue(CastKeeperCue.locked);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_figure(tester).feeling, CastFeeling.happy);
    expect(_figure(tester).animate, isTrue);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(_figure(tester).feeling, CastFeeling.calm);
    expect(_figure(tester).animate, isFalse);
    expect(CastKeeperCues.latest.value, isNull);
  });

  testWidgets('after an open: surprised, then happy, then rest',
      (tester) async {
    await pumpRedesign(tester, _screen(), castOn: true);
    await tester.pumpAndSettle();
    CastKeeperCues.cue(CastKeeperCue.opened);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_figure(tester).feeling, CastFeeling.surprised);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(_figure(tester).feeling, CastFeeling.happy);

    await tester.pump(const Duration(milliseconds: 1800));
    expect(_figure(tester).feeling, CastFeeling.calm);
  });

  testWidgets('with reduced motion it only changes its face', (tester) async {
    await pumpRedesign(tester, _screen(), castOn: true, reduceMotion: true);
    await tester.pumpAndSettle();
    CastKeeperCues.cue(CastKeeperCue.locked);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_figure(tester).feeling, CastFeeling.happy);
    expect(_figure(tester).animate, isFalse);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  test('a cue goes stale and is taken once', () {
    var now = DateTime(2026, 10, 27, 9);
    CastKeeperCues.clock = () => now;
    CastKeeperCues.cue(CastKeeperCue.opened);
    expect(CastKeeperCues.take(), CastKeeperCue.opened);
    expect(CastKeeperCues.take(), isNull);

    CastKeeperCues.cue(CastKeeperCue.locked);
    now = now.add(const Duration(minutes: 3));
    expect(CastKeeperCues.take(), isNull);
  });
}
