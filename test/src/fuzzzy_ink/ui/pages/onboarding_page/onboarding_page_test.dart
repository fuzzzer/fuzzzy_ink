import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

import '../../../../../helpers/access_harness.dart';

/// The first run's opening (prototype `ob-welcome`, `ob-how`): Welcome, then
/// How it works, then the master password. "Why once?" carries the
/// opens-once explanation that used to be the last slide.
void main() {
  late AccessHarness harness;
  final en = FuzzzyInkLocalizationsEn();
  final ka = FuzzzyInkLocalizationsKa();

  setUp(() async {
    harness = AccessHarness();
    await harness.setUp();
  });

  tearDown(() => harness.tearDown());

  testWidgets('Welcome: the mark, one line, the offline tag and Start',
      (tester) async {
    await harness.pump(tester, const OnboardingPage());

    expect(find.byKey(const Key('mark.welcome')), findsOneWidget);
    expect(find.text(en.accessWelcomeLine), findsOneWidget);
    expect(find.text(en.accessWelcomeTag.toUpperCase()), findsOneWidget);
    expect(find.text(en.accessStart), findsOneWidget);
    // Not a private screen.
    expect(
      SensitiveScreen.isIn(tester.element(find.text(en.accessWelcomeLine))),
      isFalse,
    );
  });

  testWidgets('the language chip opens the Language sheet', (tester) async {
    await harness.pump(tester, const OnboardingPage());
    await tester.tap(find.byKey(const Key('btn.welcome.language')));
    await tester.pumpAndSettle();
    expect(find.text(en.languageEnglish), findsWidgets);
    expect(find.text(en.languageGeorgian), findsWidgets);
  });

  for (final (locale, l10n) in [
    (const Locale('en'), en),
    (const Locale('ka'), ka),
  ]) {
    testWidgets(
        'Start shows How it works; "Why once?" explains opening once '
        '(${locale.languageCode})', (tester) async {
      await harness.pump(tester, const OnboardingPage(), locale: locale);
      await tester.tap(find.text(l10n.accessStart));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accessHowAddPerson), findsOneWidget);
      expect(find.text(l10n.accessHowLockForThem), findsOneWidget);
      expect(find.text(l10n.accessHowTheyOpenOnce), findsOneWidget);
      expect(find.text(l10n.accessHowTip), findsOneWidget);

      await tester.tap(find.text(l10n.accessWhyOnce));
      await tester.pumpAndSettle();
      expect(find.text(l10n.infoOpensOnceTitle), findsOneWidget);
      expect(find.text(l10n.infoOpensOnceLine2), findsOneWidget);
    });
  }

  testWidgets('Next remembers the opening was seen and goes to the password',
      (tester) async {
    await harness.pump(tester, const OnboardingPage(initialPage: 1));
    expect(sl.get<PreferencesService>().hasSeenOnboarding, isFalse);

    await tester.tap(find.text(en.next));
    await tester.pumpAndSettle();

    expect(sl.get<PreferencesService>().hasSeenOnboarding, isTrue);
    expect(find.text('route:${AppRouter.setup}'), findsOneWidget);
  });

  testWidgets('back from How it works shows Welcome again', (tester) async {
    await harness.pump(tester, const OnboardingPage(initialPage: 1));
    await tester.tap(find.byKey(const Key('how.back')));
    await tester.pumpAndSettle();
    expect(find.text(en.accessWelcomeLine), findsOneWidget);
  });

  forEveryLook('Welcome and How it works fit', (
    tester,
    skin,
    reduceMotion,
    textScale,
  ) async {
    await harness.pump(
      tester,
      const OnboardingPage(),
      skin: skin,
      reduceMotion: reduceMotion,
      textScale: textScale,
      surface: const Size(390, 844),
    );
    await tester.tap(find.text(en.accessStart));
    await tester.pumpAndSettle();
    expect(find.text(en.accessHowTip), findsOneWidget);
  });
}
