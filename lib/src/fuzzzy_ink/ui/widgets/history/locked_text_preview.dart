import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A short, faded look at locked text (mono, clipped to a few lines with a
/// fade at the bottom), so the person sees it is unreadable. Not selectable;
/// copying goes through "Copy locked text" or Share. [showLabel] puts
/// "Locked version · safe to send" above it.
class LockedTextPreview extends StatelessWidget {
  const LockedTextPreview({
    super.key,
    required this.lockedText,
    this.showLabel = false,
    this.qaId,
  });

  final String lockedText;
  final bool showLabel;
  final String? qaId;

  /// From the design (`.sealed`): about four lines.
  static const double maxHeight = 84;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final localizations = context.fuzzzyInkLocalizations;

    final box = Container(
      key: qaId == null ? null : Key('locked_preview.$qaId'),
      constraints: const BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Padding(
            padding: context.fuzzzyDensity.snug,
            child: Text(
              lockedText,
              softWrap: true,
              overflow: TextOverflow.clip,
              style: type.data.copyWith(color: colors.inkMute),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.surface.withValues(alpha: 0), colors.surface],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: localizations.lockedPreviewLabel,
      container: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showLabel) ...[
              Text(
                localizations.lockedPreviewLabel.toUpperCase(),
                style: type.label.copyWith(color: colors.inkMute),
              ),
              SizedBox(height: context.fuzzzySpace.s),
            ],
            box,
          ],
        ),
      ),
    );
  }
}
