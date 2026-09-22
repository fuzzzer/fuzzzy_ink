import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

void main() {
  testWidgets('every section of the trade-off copy is on the page',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: const AboutEncryptionPage(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = FuzzzyInkLocalizations.of(
      tester.element(find.byType(AboutEncryptionPage)),
    )!;
    for (final text in [
      l10n.aboutEncryptionTitle,
      l10n.forwardSecrecyNotice,
      l10n.aboutEncryptionBodyHistory,
      l10n.aboutEncryptionBodyWindow,
      l10n.aboutEncryptionBodyLinks,
      l10n.aboutEncryptionBodyErrors,
      l10n.aboutEncryptionBodySafetyNumber,
      l10n.aboutEncryptionBodyUnderTheHood,
    ]) {
      expect(find.text(text, skipOffstage: false), findsOneWidget);
    }
    expect(l10n.aboutEncryptionBodyWindow, contains('63'));
    expect(l10n.aboutEncryptionBodyLinks, contains('chat’s id'));
  });
}
