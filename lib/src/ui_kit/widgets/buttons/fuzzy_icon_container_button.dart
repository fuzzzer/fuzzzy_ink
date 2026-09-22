import 'package:flutter/material.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class FuzzyIconContainerButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;

  const FuzzyIconContainerButton({
    required this.onTap,
    super.key,
    this.icon,
    this.backgroundColor,
    this.iconColor,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: backgroundColor ?? fuzzzyColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            icon,
            color: iconColor ?? fuzzzyColors.ground,
            size: 30,
          ),
        ),
      ),
    );
  }
}
