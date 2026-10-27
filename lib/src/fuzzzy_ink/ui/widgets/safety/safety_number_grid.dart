import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The numbers two people compare: 12 groups of 5 digits in three columns
/// (two at large text sizes), mono. The numbers are not secret, so the grid
/// is not a private screen and screen readers read every group.
class SafetyNumberGrid extends StatelessWidget {
  const SafetyNumberGrid({super.key, required this.groups, this.qaId});

  /// Usually 12 groups of 5 digits.
  final List<String> groups;
  final String? qaId;

  /// Splits a 60-digit safety number into its groups of five.
  static List<String> groupsOf(String digits, {int size = 5}) {
    final clean = digits.replaceAll(RegExp(r'\s'), '');
    return [
      for (var i = 0; i < clean.length; i += size)
        clean.substring(i, i + size > clean.length ? clean.length : i + size),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final columns = MediaQuery.textScalerOf(context).scale(1) >= 2 ? 2 : 3;
    final style = context.fuzzzyTextStyles.dataL.copyWith(color: colors.ink);

    final rows = <Widget>[];
    for (var i = 0; i < groups.length; i += columns) {
      if (i > 0) rows.add(SizedBox(height: space.m));
      rows.add(
        Row(
          children: [
            for (var c = 0; c < columns; c++)
              Expanded(
                child: i + c < groups.length
                    ? Text(
                        groups[i + c],
                        textAlign: TextAlign.center,
                        style: style,
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      );
    }

    return Semantics(
      identifier: qaId == null ? null : 'safety_grid.$qaId',
      label: context.fuzzzyInkLocalizations.safetyGridLabel,
      container: true,
      child: Container(
        key: qaId == null ? null : Key('safety_grid.$qaId'),
        padding:
            EdgeInsets.symmetric(vertical: space.l + 2, horizontal: space.s),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(context.fuzzzyRadius.l),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}
