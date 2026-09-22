import 'package:flutter/material.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class FuzzyToolbox extends StatelessWidget {
  final List<Widget> children;

  const FuzzyToolbox({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;

    return Material(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(12),
      color: fuzzzyColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
