import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The plain-language trade-off copy (owner decision D-1): what single-use
/// unfuzzing costs, how history is kept, the window limit, message links,
/// what the errors mean, the safety number, and one paragraph on the core.
class AboutEncryptionPage extends StatelessWidget {
  const AboutEncryptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzyInkLocalizations;

    final sections = <(String, String)>[
      (localizations.forwardSecrecyTitle, localizations.forwardSecrecyNotice),
      (
        localizations.aboutEncryptionHistoryTitle,
        localizations.aboutEncryptionBodyHistory,
      ),
      (
        localizations.aboutEncryptionWindowTitle,
        localizations.aboutEncryptionBodyWindow,
      ),
      (
        localizations.aboutEncryptionLinksTitle,
        localizations.aboutEncryptionBodyLinks,
      ),
      (
        localizations.aboutEncryptionErrorsTitle,
        localizations.aboutEncryptionBodyErrors,
      ),
      (
        localizations.safetyNumberTitle,
        localizations.aboutEncryptionBodySafetyNumber,
      ),
      (
        localizations.aboutEncryptionUnderTheHoodTitle,
        localizations.aboutEncryptionBodyUnderTheHood,
      ),
    ];

    return FuzzyScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FuzzzyAppBar(
                title: localizations.aboutEncryptionTitle,
              ),
              for (final (title, body) in sections) ...[
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.start,
                  style: fuzzzyTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: fuzzzyColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.start,
                  style: fuzzzyTextStyles.body.copyWith(
                    color: fuzzzyColors.inkMute,
                  ),
                ),
              ],
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}
