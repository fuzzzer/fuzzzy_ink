import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// One small guiding line: an icon, a short sentence and, optionally, a
/// "Why?" link after it ("No key? Then nothing can open it. Why?").
class TipLine extends StatelessWidget {
  const TipLine({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.trailing,
    this.qaId,
  });

  final String text;
  final IconData icon;

  /// Usually a [WhyLink].
  final Widget? trailing;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final style = context.fuzzzyTextStyles.bodyS.copyWith(
      color: colors.inkMute,
    );
    final trailing = this.trailing;

    return Row(
      key: qaId == null ? null : Key('tip.$qaId'),
      children: [
        ExcludeSemantics(
          child:
              Icon(icon, size: context.fuzzzyIconSize.s, color: colors.inkMute),
        ),
        SizedBox(width: space.s),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: space.s * 0.75,
            children: [
              Text(text, style: style),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ],
    );
  }
}
