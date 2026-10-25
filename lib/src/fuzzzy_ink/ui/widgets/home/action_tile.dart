import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Home's big tile: an icon, one big word and one line ("Lock · For one
/// person"). [inverted] uses the main-action colours (Lock); otherwise it is
/// a surface tile with a hairline (Open). Grows taller with large text.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.inverted = false,
    required this.qaId,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool inverted;
  final String qaId;

  /// From the design (`.tile`): 150 px tall at normal text size.
  static const double minHeight = 150;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final radius = context.fuzzzyRadius.l;
    final background = inverted ? colors.actionPrimaryBg : colors.surface;
    final foreground = inverted ? colors.actionPrimaryFg : colors.ink;
    final border = inverted ? colors.actionPrimaryBg : colors.line;
    final motion = context.fuzzzyMotion;

    return Semantics(
      identifier: 'tile.$qaId',
      button: true,
      container: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: FuzzzyTappable(
        key: Key('tile.$qaId'),
        onTap: onTap,
        focusRadius: radius,
        builder: (context, active) => AnimatedScale(
          scale: active ? 0.98 : 1,
          duration: InkMotion.isReduced(context) ? Duration.zero : motion.fast,
          curve: motion.fastCurve,
          child: Container(
            constraints: const BoxConstraints(minHeight: minHeight),
            padding: context.fuzzzyDensity.card,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: context.fuzzzyIconSize.l * 1.7,
                  color: foreground,
                ),
                SizedBox(height: context.fuzzzySpace.l),
                Text(
                  title,
                  style: type.titleL.copyWith(
                    color: foreground,
                    fontFamily: type.displayL.fontFamily,
                    fontWeight: type.displayL.fontWeight,
                  ),
                ),
                SizedBox(height: context.fuzzzySpace.xs),
                Text(
                  subtitle,
                  style: type.bodyS.copyWith(
                    color: foreground.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
