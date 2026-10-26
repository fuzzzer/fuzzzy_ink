import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Settings → Privacy, terms and support (prototype `set-legal`): the four
/// fuzzzycore.com pages, each opened in the system browser. The app itself
/// never goes online.
class LegalLinksPage extends StatelessWidget {
  const LegalLinksPage({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    final isOpened = await ExternalLinks.open(uri);
    if (isOpened || !context.mounted) return;
    showInkToast(
      context,
      message: context.fuzzzyInkLocalizations.couldNotOpenLink,
      kind: FuzzzyToastKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final links = [
      (
        'privacy',
        Icons.privacy_tip_outlined,
        localizations.privacyPolicy,
        ExternalLinks.privacyPolicy
      ),
      (
        'terms',
        Icons.description_outlined,
        localizations.termsOfUse,
        ExternalLinks.terms
      ),
      (
        'support',
        Icons.help_outline,
        localizations.support,
        ExternalLinks.support
      ),
      (
        'deletion',
        Icons.delete_outline,
        localizations.dataDeletion,
        ExternalLinks.dataDeletion
      ),
    ];

    return AccessPage(
      qaId: 'legal',
      title: localizations.accessPrivacyTermsSupport,
      onBack: () => leaveAccessPage(context),
      children: [
        TipLine(
          icon: Icons.public,
          text: localizations.accessBrowserTip,
          qaId: 'legal.browser',
        ),
        SizedBox(height: context.fuzzzySpace.m),
        for (final (index, (id, icon, title, uri)) in links.indexed)
          FuzzzyListTile(
            qaId: 'legal.$id',
            leading: SettingsRowIcon(icon),
            title: SettingsRowText(title: title),
            trailing: Icon(
              Icons.open_in_new,
              size: context.fuzzzyIconSize.m,
              color: context.fuzzzyColors.inkMute,
            ),
            divider: index < links.length - 1,
            onTap: () => _open(context, uri),
          ),
      ],
    );
  }
}
