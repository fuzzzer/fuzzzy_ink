import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The actions a bubble spawns, as stacked pills of at most [maxPerRow]
/// [TextAction]s each, so every action stays on a 360dp-wide phone
/// (T-0366). Each row is its own rounded pill; the actions' own end borders
/// are set here.
class FuzzyActionPill extends StatelessWidget {
  const FuzzyActionPill({
    super.key,
    required this.actions,
    this.maxPerRow = 3,
    this.alignment = CrossAxisAlignment.start,
  });

  final List<TextAction> actions;
  final int maxPerRow;

  /// Rows line up with the bubble's edge: `end` for a sent bubble.
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;

    final rows = <List<TextAction>>[
      for (var start = 0; start < actions.length; start += maxPerRow)
        actions.sublist(
          start,
          (start + maxPerRow).clamp(0, actions.length),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        for (final (rowIndex, row) in rows.indexed) ...[
          if (rowIndex > 0) const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: fuzzzyColors.focus,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, action) in row.indexed) ...[
                  if (index > 0) const SizedBox(width: 2),
                  TextAction(
                    key: action.key,
                    label: action.label,
                    onTap: action.onTap,
                    hasLeftBorder: index == 0,
                    hasRightBorder: index == row.length - 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
