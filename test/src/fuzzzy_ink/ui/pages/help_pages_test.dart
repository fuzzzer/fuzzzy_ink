import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/access_harness.dart';

/// Records every launch instead of opening anything.
class FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launches = <(String, PreferredLaunchMode)>[];
  bool answer = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url, options.mode));
    return answer;
  }
}

/// Settings → How Fuzzzy Ink works and Privacy, terms and support
/// (prototype `set-how`, `set-legal`): not private.
void main() {
  late AccessHarness harness;
  late FakeUrlLauncher urlLauncher;
  final l10n = FuzzzyInkLocalizationsEn();

  setUp(() async {
    harness = AccessHarness();
    await harness.setUp();
    urlLauncher = FakeUrlLauncher();
    UrlLauncherPlatform.instance = urlLauncher;
  });

  tearDown(() => harness.tearDown());

  group('How Fuzzzy Ink works', () {
    testWidgets('the cards, then each fact one tap away', (tester) async {
      await harness.pump(
        tester,
        const HowItWorksPage(),
        surface: const Size(390, 1600),
      );
      expect(find.text(l10n.accessHowAddPerson), findsOneWidget);
      expect(find.text(l10n.accessHowOnceTitle), findsOneWidget);
      expect(
        SensitiveScreen.isIn(
          tester.element(find.text(l10n.accessHowOnceTitle)),
        ),
        isFalse,
      );

      await tester.tap(find.text(l10n.accessHowHoodTitle));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accessHowHoodBody), findsOneWidget);

      await tester.tap(find.text(l10n.accessMoreAboutEncryption));
      await tester.pumpAndSettle();
      expect(find.text('route:${AppRouter.aboutEncryption}'), findsOneWidget);
    });
  });

  group('Privacy, terms and support', () {
    testWidgets('each link hands the exact fuzzzycore.com page to the browser',
        (tester) async {
      await harness.pump(tester, const LegalLinksPage());
      expect(find.text(l10n.accessBrowserTip), findsOneWidget);
      for (final title in [
        l10n.privacyPolicy,
        l10n.termsOfUse,
        l10n.support,
        l10n.dataDeletion,
      ]) {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }
      expect(urlLauncher.launches, [
        (
          'https://fuzzzycore.com/privacy',
          PreferredLaunchMode.externalApplication,
        ),
        (
          'https://fuzzzycore.com/terms',
          PreferredLaunchMode.externalApplication,
        ),
        (
          'https://fuzzzycore.com/support',
          PreferredLaunchMode.externalApplication,
        ),
        (
          'https://fuzzzycore.com/account-deletion',
          PreferredLaunchMode.externalApplication,
        ),
      ]);
    });

    testWidgets('a link no app can open says so', (tester) async {
      urlLauncher.answer = false;
      await harness.pump(tester, const LegalLinksPage());
      await tester.tap(find.text(l10n.privacyPolicy));
      await tester.pump();
      expect(find.text(l10n.couldNotOpenLink), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  forEveryLook('both help screens fit', (
    tester,
    skin,
    reduceMotion,
    textScale,
  ) async {
    for (final page in const [HowItWorksPage(), LegalLinksPage()]) {
      await harness.pump(
        tester,
        page,
        skin: skin,
        reduceMotion: reduceMotion,
        textScale: textScale,
        surface: const Size(390, 844),
      );
      expect(tester.takeException(), isNull, reason: '$page');
    }
  });
}
