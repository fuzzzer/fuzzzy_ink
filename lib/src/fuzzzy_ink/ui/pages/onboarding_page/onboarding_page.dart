import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// The first run's opening (DESIGN.md section 4.1, prototype `ob-welcome`
/// and `ob-how`): Welcome (the mark, one line, Start, the language chip),
/// then How it works (three picture cards, "Why once?", one tip, Next). Next
/// leads to the master password.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.initialPage = 0});

  /// 0 Welcome, 1 How it works (back from the master password step).
  final int initialPage;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late int _page = widget.initialPage.clamp(0, 1);

  Future<void> _onNext() async {
    await sl.get<PreferencesService>().setHasSeenOnboarding(true);
    if (mounted) context.go(AppRouter.setup);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: InkMotion.isReduced(context)
          ? Duration.zero
          : context.fuzzzyMotion.standard,
      child: _page == 0
          ? _WelcomeView(
              key: const ValueKey('welcome'),
              onStart: () => setState(() => _page = 1),
            )
          : _HowItWorksView(
              key: const ValueKey('how'),
              onBack: () => setState(() => _page = 0),
              onNext: _onNext,
            ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final language = SettingsLookAndLanguageSection.languageName(
      localizations,
      SettingsLookAndLanguageSection.languageChoiceOf(
        context.watch<LocalizationCubit>().state,
      ),
    );

    return AccessPage(
      qaId: 'welcome',
      centerContent: true,
      bottom: [
        FuzzzyButton(
          label: localizations.accessStart,
          size: FuzzzyButtonSize.l,
          qaId: 'welcome.start',
          onPressed: onStart,
        ),
      ],
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FuzzzyButton(
            label: language,
            variant: FuzzzyButtonVariant.ghost,
            size: FuzzzyButtonSize.s,
            icon: const Icon(Icons.translate),
            qaId: 'welcome.language',
            onPressed: () => showLanguageSheet(context),
          ),
        ),
        SizedBox(height: space.xl),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkMark(size: 96, qaId: 'welcome'),
        ),
        SizedBox(height: space.l),
        Semantics(
          header: true,
          child: Text(
            localizations.fuzzzyInk,
            style:
                context.fuzzzyTextStyles.displayL.copyWith(color: colors.ink),
          ),
        ),
        SizedBox(height: space.m),
        Text(
          localizations.accessWelcomeLine,
          style: context.fuzzzyTextStyles.titleM.copyWith(color: colors.ink),
        ),
        SizedBox(height: space.l),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: KeyTag(
            icon: Icons.shield_outlined,
            label: localizations.accessWelcomeTag,
            qaId: 'welcome.offline',
          ),
        ),
      ],
    );
  }
}

class _HowItWorksView extends StatelessWidget {
  const _HowItWorksView({
    super.key,
    required this.onBack,
    required this.onNext,
  });

  final VoidCallback onBack;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return AccessPage(
      qaId: 'how',
      title: localizations.accessHowItWorks,
      onBack: onBack,
      bottom: [
        FuzzzyButton(
          label: localizations.next,
          size: FuzzzyButtonSize.l,
          qaId: 'how.next',
          onPressed: () => unawaited(onNext()),
        ),
      ],
      children: [
        const HowItWorksCards(numbered: true),
        SizedBox(height: space.m),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FuzzzyButton(
            label: localizations.accessWhyOnce,
            variant: FuzzzyButtonVariant.ghost,
            size: FuzzzyButtonSize.s,
            icon: const Icon(Icons.help_outline),
            qaId: 'how.whyOnce',
            onPressed: () => showInkInfoSheet(context, InkInfoTopic.opensOnce),
          ),
        ),
        SizedBox(height: space.m),
        TipLine(
          icon: Icons.key_outlined,
          text: localizations.accessHowTip,
          qaId: 'how.masterPassword',
        ),
      ],
    );
  }
}

/// The three picture cards of "How it works": Add a person · Lock for them
/// · They open it, once. Side by side, stacked when the text is large.
class HowItWorksCards extends StatelessWidget {
  const HowItWorksCards({super.key, this.numbered = false});

  /// Numbers 1–3 on the cards (the first run).
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final cards = [
      (Icons.person_add_alt, localizations.accessHowAddPerson, false),
      (Icons.lock_outline, localizations.accessHowLockForThem, true),
      (CupertinoIcons.lock_open, localizations.accessHowTheyOpenOnce, false),
    ];
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.4;

    final items = [
      for (final (index, (icon, label, inverted)) in cards.indexed)
        _PictureCard(
          number: numbered ? index + 1 : null,
          icon: icon,
          label: label,
          inverted: inverted,
          horizontal: stacked,
        ),
    ];

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) SizedBox(height: space.s),
            item,
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) SizedBox(width: space.s),
            Expanded(child: item),
          ],
        ],
      ),
    );
  }
}

class _PictureCard extends StatelessWidget {
  const _PictureCard({
    required this.number,
    required this.icon,
    required this.label,
    required this.inverted,
    required this.horizontal,
  });

  final int? number;
  final IconData icon;
  final String label;
  final bool inverted;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final number = this.number;
    final glyph = ExcludeSemantics(
      child: Container(
        width: kFuzzzyMinTouchTarget,
        height: kFuzzzyMinTouchTarget,
        decoration: BoxDecoration(
          color: inverted ? colors.actionPrimaryBg : colors.raised,
          border: Border.all(
            color: inverted ? colors.actionPrimaryBg : colors.line,
          ),
          borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
        ),
        child: Icon(
          icon,
          size: context.fuzzzyIconSize.l,
          color: inverted ? colors.actionPrimaryFg : colors.ink,
        ),
      ),
    );
    final text = Text(
      label,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: context.fuzzzyTextStyles.bodyS.copyWith(
        color: colors.ink,
        fontWeight: FontWeight.w600,
      ),
    );
    final numberText = number == null
        ? null
        : Text(
            '$number',
            style:
                context.fuzzzyTextStyles.data.copyWith(color: colors.inkMute),
          );

    return Container(
      padding: EdgeInsets.all(space.m),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
      ),
      child: horizontal
          ? Row(
              children: [
                if (numberText != null) ...[
                  numberText,
                  SizedBox(width: space.s),
                ],
                glyph,
                SizedBox(width: space.m),
                Expanded(child: text),
              ],
            )
          : Column(
              children: [
                if (numberText != null) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: numberText,
                  ),
                  SizedBox(height: space.xs),
                ],
                glyph,
                SizedBox(height: space.s),
                text,
              ],
            ),
    );
  }
}
