import 'package:flutter/material.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class FuzzyHeader extends StatelessWidget {
  final String title;

  final TextAlign textAlign;
  final Widget? leftAction;
  final Widget? rightAction;

  const FuzzyHeader({
    required this.title,
    super.key,
    this.textAlign = TextAlign.center,
    this.leftAction,
    this.rightAction,
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 32,
            child: leftAction,
          ),
          const Spacer(),
          Text(
            title,
            style: fuzzzyTextStyles.titleM.copyWith(
              color: context.fuzzzyColors.ink,
            ),
            textAlign: textAlign,
          ),
          const Spacer(),
          SizedBox.square(
            dimension: 32,
            child: rightAction,
          ),
        ],
      ),
    );
  }
}
