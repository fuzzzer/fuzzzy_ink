import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A small mono tag that names a rule in force: "NO COPY · NO SCREENSHOTS"
/// under a recovery key, "NO COPY" under opened text. Defaults to the
/// recovery key's tag.
class KeyTag extends StatelessWidget {
  const KeyTag({
    super.key,
    this.label,
    this.icon = Icons.lock_outline,
    this.qaId,
  });

  /// Null shows "No copy · no screenshots".
  final String? label;
  final IconData icon;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final text = label ?? context.fuzzzyInkLocalizations.tagNoCopyNoScreenshots;
    final style = context.fuzzzyTextStyles.label;

    return Semantics(
      label: text,
      container: true,
      child: ExcludeSemantics(
        child: Row(
          key: qaId == null ? null : Key('tag.$qaId'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.fuzzzyIconSize.s * 0.8,
              color: colors.inkMute,
            ),
            SizedBox(width: context.fuzzzySpace.xs * 1.5),
            Flexible(
              child: Text(
                // Georgian has no capitals: the upper-casing leaves it as is.
                text.toUpperCase(),
                style: style.copyWith(color: colors.inkMute),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
