import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// Settings → How Fuzzzy Ink works (prototype `set-how`): the three picture
/// cards, then the facts in plain words, one tap each. "Under the hood"
/// keeps the exact technical names and leads to the full page about
/// encryption.
class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final body = context.fuzzzyTextStyles.bodyS
        .copyWith(color: context.fuzzzyColors.inkMute);
    final facts = [
      (
        'once',
        localizations.accessHowOnceTitle,
        localizations.accessHowOnceBody
      ),
      (
        'history',
        localizations.accessHowHistoryTitle,
        localizations.accessHowHistoryBody,
      ),
      (
        'order',
        localizations.accessHowOrderTitle,
        localizations.accessHowOrderBody,
      ),
      (
        'check',
        localizations.accessHowCheckTitle,
        localizations.accessHowCheckBody,
      ),
      (
        'links',
        localizations.accessHowLinksTitle,
        localizations.accessHowLinksBody,
      ),
      (
        'files',
        localizations.accessHowFilesTitle,
        localizations.accessHowFilesBody,
      ),
    ];

    return AccessPage(
      qaId: 'howItWorks',
      title: localizations.accessHowFuzzzyInkWorks,
      onBack: () => leaveAccessPage(context),
      children: [
        const HowItWorksCards(),
        SizedBox(height: space.l),
        for (final (id, title, text) in facts)
          FuzzzyAccordion(
            qaId: 'how.$id',
            title: title,
            child: Text(text, style: body),
          ),
        FuzzzyAccordion(
          qaId: 'how.hood',
          title: localizations.accessHowHoodTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.accessHowHoodBody, style: body),
              SizedBox(height: space.s),
              FuzzzyButton(
                label: localizations.accessMoreAboutEncryption,
                variant: FuzzzyButtonVariant.ghost,
                size: FuzzzyButtonSize.s,
                qaId: 'how.aboutEncryption',
                onPressed: () => context.push(AppRouter.aboutEncryption),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
