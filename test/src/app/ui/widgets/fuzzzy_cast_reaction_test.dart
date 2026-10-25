import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_cast/fuzzzy_cast.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/redesign_harness.dart';

const _glyph = HeroGlyph(icon: Icons.lock_outline, qaId: 'glyph');

Widget _reaction(FuzzzyCastMoment moment) => Center(
      child: FuzzzyCastReaction(moment: moment, fallback: _glyph),
    );

CastFigure _figure(WidgetTester tester) =>
    tester.widget<CastFigure>(find.byType(CastFigure));

void main() {
  setUp(FuzzzyCastThrottle.reset);
  tearDown(FuzzzyCastThrottle.reset);

  group('FuzzzyCastReaction', () {
    testWidgets('Fuzzzy Cast off: the glyph response shows', (tester) async {
      await pumpRedesign(tester, _reaction(FuzzzyCastMoment.locked));
      expect(find.byKey(const Key('hero.glyph')), findsOneWidget);
      expect(find.byType(CastFigure), findsNothing);
    });

    for (final skin in redesignSkins) {
      testWidgets(
          'Fuzzzy Cast on: Fuzzz replaces the glyph, plays once, then rests '
          '($skin)', (tester) async {
        await pumpRedesign(
          tester,
          _reaction(FuzzzyCastMoment.locked),
          skin: skin,
          castOn: true,
        );
        expect(find.byKey(const Key('hero.glyph')), findsNothing);
        expect(_figure(tester).character, CastCharacters.fuzzz);
        expect(_figure(tester).feeling, CastFeeling.determined);
        expect(_figure(tester).animate, isTrue);
        expect(
          _figure(tester).ground,
          skin == FuzzzySkin.paper ? CastGround.paper : CastGround.night,
        );

        await tester.pump(FuzzzyCastMoment.locked.length);
        await tester.pump();
        expect(_figure(tester).feeling, CastFeeling.calm);
        expect(_figure(tester).animate, isFalse);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('never on a private screen', (tester) async {
      await pumpRedesign(
        tester,
        _reaction(FuzzzyCastMoment.opened),
        castOn: true,
        private: true,
      );
      expect(find.byType(CastFigure), findsNothing);
      expect(find.byKey(const Key('hero.glyph')), findsOneWidget);
    });

    testWidgets('reduced motion: a still Fuzzz', (tester) async {
      await pumpRedesign(
        tester,
        _reaction(FuzzzyCastMoment.checked),
        castOn: true,
        reduceMotion: true,
      );
      expect(_figure(tester).animate, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the same moment plays at most once a minute', (tester) async {
      var now = DateTime(2026, 10, 26, 9);
      FuzzzyCastThrottle.clock = () => now;

      await pumpRedesign(
        tester,
        _reaction(FuzzzyCastMoment.connected),
        castOn: true,
      );
      expect(_figure(tester).animate, isTrue);
      await tester.pumpWidget(const SizedBox());

      now = now.add(const Duration(seconds: 20));
      await pumpRedesign(
        tester,
        _reaction(FuzzzyCastMoment.connected),
        castOn: true,
      );
      expect(_figure(tester).animate, isFalse, reason: 'resting, not again');
      await tester.pumpWidget(const SizedBox());

      now = now.add(const Duration(minutes: 1));
      await pumpRedesign(
        tester,
        _reaction(FuzzzyCastMoment.connected),
        castOn: true,
      );
      expect(_figure(tester).animate, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hidden from screen readers and not tappable', (tester) async {
      await pumpRedesign(
        tester,
        _reaction(FuzzzyCastMoment.noPeople),
        castOn: true,
      );
      expect(
        find.ancestor(
          of: find.byType(CastFigure),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(
          of: find.byType(CastFigure),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('showInkToast', () {
    Widget host() => Builder(
          builder: (context) => TextButton(
            onPressed: () => showInkToast(
              context,
              message: 'In Nino’s history now.',
              castMoment: FuzzzyCastMoment.opened,
            ),
            child: const Text('go'),
          ),
        );

    testWidgets('Fuzzz rides along when Fuzzzy Cast is on', (tester) async {
      await pumpRedesign(tester, host(), castOn: true);
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.text('In Nino’s history now.'), findsOneWidget);
      expect(find.byType(CastFigure), findsOneWidget);
      expect(_figure(tester).size, 46);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('In Nino’s history now.'), findsNothing);
    });

    testWidgets('a plain toast when it is off', (tester) async {
      await pumpRedesign(tester, host());
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.text('In Nino’s history now.'), findsOneWidget);
      expect(find.byType(CastFigure), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('FuzzzyCastSettingsCubit', () {
    late PreferencesService preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = PreferencesService(await SharedPreferences.getInstance());
    });

    test('both switches start off', () {
      final cubit = FuzzzyCastSettingsCubit(preferencesService: preferences);
      expect(
        cubit.state,
        const FuzzzyCastSettingsState(isEnabled: false, softSounds: false),
      );
    });

    blocTest<FuzzzyCastSettingsCubit, FuzzzyCastSettingsState>(
      'keeps each choice on the device',
      build: () => FuzzzyCastSettingsCubit(preferencesService: preferences),
      act: (cubit) async {
        await cubit.setEnabled(true);
        await cubit.setSoftSounds(true);
      },
      expect: () => const [
        FuzzzyCastSettingsState(isEnabled: true, softSounds: false),
        FuzzzyCastSettingsState(isEnabled: true, softSounds: true),
      ],
      verify: (_) {
        expect(preferences.fuzzzyCastEnabled, isTrue);
        expect(preferences.fuzzzyCastSoftSounds, isTrue);
      },
    );
  });
}
