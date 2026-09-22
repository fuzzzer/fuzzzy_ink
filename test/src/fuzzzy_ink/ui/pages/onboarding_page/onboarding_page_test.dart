import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The forward-secrecy trade-off (owner decision D-1) is the last onboarding
/// slide, in both locales.
void main() {
  const enNotice = 'Each fuzzed message can be unfuzzed once, on this device '
      'only. Your history stays in the app — export an archive to back it up. '
      'A new device cannot re-read old blobs.';
  const kaNotice = 'თითოეული დაშიფრული შეტყობინების გაშიფვრა მხოლოდ ერთხელ და '
      'მხოლოდ ამ მოწყობილობაზე შეიძლება. თქვენი ისტორია აპლიკაციაში რჩება — '
      'სარეზერვო ასლისთვის არქივის ექსპორტი გააკეთეთ. ახალ მოწყობილობას ძველი '
      'შეტყობინებების ხელახლა წაკითხვა არ შეუძლია.';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.safeRegisterSingleton<PreferencesService>(
      PreferencesService(await SharedPreferences.getInstance()),
    );
  });

  tearDown(() async {
    await sl.unregister<PreferencesService>();
  });

  Future<void> pumpOnboarding(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        locale: locale,
        home: const OnboardingPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  }

  for (final (locale, notice, cta) in [
    (const Locale('en'), enNotice, 'Get Started'),
    (const Locale('ka'), kaNotice, 'დაწყება'),
  ]) {
    testWidgets(
        'the fourth slide carries the forward-secrecy notice '
        '(${locale.languageCode})', (tester) async {
      await pumpOnboarding(tester, locale);
      expect(find.text(notice), findsNothing);

      await next(tester);
      await next(tester);
      await next(tester);

      expect(find.text(notice), findsOneWidget);
      expect(find.text(cta), findsOneWidget);
    });
  }

  // T-0335: at 411 dp the ka title's last word was wider than the column at
  // the display size, so it broke inside the word ("მოწყობილობაზ / ე"). The
  // title steps its style down until every word fits; en keeps the display
  // size.
  for (final (locale, title, width) in [
    (const Locale('ka'), 'იშიფრება ერთხელ, ამ მოწყობილობაზე', 411.0),
    (const Locale('ka'), 'იშიფრება ერთხელ, ამ მოწყობილობაზე', 360.0),
    (const Locale('en'), 'Unfuzzed once, on this device', 411.0),
  ]) {
    testWidgets(
        'the fourth slide title only wraps between words '
        '(${locale.languageCode}, $width dp)', (tester) async {
      tester.view.physicalSize = Size(width, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpOnboarding(tester, locale);
      await next(tester);
      await next(tester);
      await next(tester);

      final text = tester.widget<Text>(find.text(title));
      final column = tester.getSize(find.text(title)).width;
      for (final word in title.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: text.style),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(painter.width, lessThanOrEqualTo(column), reason: word);
      }
      if (locale.languageCode == 'en') {
        final display = Theme.of(tester.element(find.text(title)))
            .textTheme
            .headlineMedium!
            .fontSize;
        expect(text.style!.fontSize, display);
      }
    });
  }
}
