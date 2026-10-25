import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The step bar at the top of a flow: one 3 px bar per step (filled up to
/// [step]) and "STEP 2 OF 3 · RECOVERY KEY" under it. Read as "Step 2 of 3,
/// Recovery key".
class StepsIndicator extends StatelessWidget {
  const StepsIndicator({
    super.key,
    required this.step,
    required this.total,
    this.label,
    this.qaId,
  }) : assert(step >= 1 && step <= total, 'step must be 1..total');

  final int step;
  final int total;
  final String? label;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final radius = context.fuzzzyRadius;
    final localizations = context.fuzzzyInkLocalizations;
    final label = this.label;
    final text = label == null
        ? localizations.stepsProgress(step, total)
        : localizations.stepsProgressWithLabel(step, total, label);

    return Semantics(
      identifier: qaId == null ? null : 'steps.$qaId',
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: Column(
          key: qaId == null ? null : Key('steps.$qaId'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) SizedBox(width: space.s * 0.75),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i < step ? colors.ink : colors.track,
                        borderRadius: BorderRadius.circular(radius.s),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: space.s),
            Text(
              text.toUpperCase(),
              style: context.fuzzzyTextStyles.label.copyWith(
                color: colors.inkMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
