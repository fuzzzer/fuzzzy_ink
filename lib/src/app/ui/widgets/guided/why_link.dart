import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The words a [WhyLink] can show.
enum WhyLinkLabel { why, how, more }

/// A small underlined "Why?" (or "How?", "More") with a help icon that opens
/// the matching explanation sheet. The visible link is small; its touch area
/// is 48 px tall. Read as "Why? Opens an explanation".
class WhyLink extends StatelessWidget {
  const WhyLink({
    super.key,
    required this.topic,
    this.label = WhyLinkLabel.why,
    this.onOpen,
    this.qaId,
  });

  final InkInfoTopic topic;
  final WhyLinkLabel label;

  /// Replaces the default sheet (a desktop popover, a test).
  final VoidCallback? onOpen;
  final String? qaId;

  /// The touch area's height (DESIGN.md section 12).
  static const double touchHeight = 48;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final text = switch (label) {
      WhyLinkLabel.why => localizations.linkWhy,
      WhyLinkLabel.how => localizations.linkHow,
      WhyLinkLabel.more => localizations.linkMore,
    };
    final id = qaId ?? topic.name;

    return Semantics(
      identifier: 'why.$id',
      button: true,
      label: text,
      hint: localizations.linkOpensExplanation,
      container: true,
      excludeSemantics: true,
      child: FuzzzyTappable(
        key: Key('why.$id'),
        onTap: onOpen ?? () => showInkInfoSheet(context, topic),
        builder: (context, active) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: touchHeight),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline,
                size: context.fuzzzyIconSize.s,
                color: active ? colors.ink : colors.inkMute,
              ),
              SizedBox(width: context.fuzzzySpace.xs),
              Text(
                text,
                style: context.fuzzzyTextStyles.bodyS.copyWith(
                  color: active ? colors.ink : colors.inkMute,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.inkMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
