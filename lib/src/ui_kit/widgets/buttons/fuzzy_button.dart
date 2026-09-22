import 'package:flutter/material.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class FuzzyButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry padding;
  final bool isEnabled;

  const FuzzyButton({
    required this.text,
    required this.onTap,
    super.key,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    ),
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 60,
        width: double.maxFinite,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isEnabled
                  ? fuzzzyColors.actionPrimaryBg
                  : fuzzzyColors.actionPrimaryBg.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  color: textColor ?? fuzzzyColors.actionPrimaryFg,
                ),
              if (icon != null) const SizedBox(width: 8),
              Text(
                text,
                style: fuzzzyTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: fuzzzyColors.actionPrimaryFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
