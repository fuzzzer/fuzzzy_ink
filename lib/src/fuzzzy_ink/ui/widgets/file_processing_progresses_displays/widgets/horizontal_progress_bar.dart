import 'package:flutter/material.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class HorizontalProgressBar extends StatelessWidget {
  const HorizontalProgressBar({
    super.key,
    this.alignment = Alignment.centerLeft,
    this.thickness = 50,
    this.width,
    this.progressColor,
    required this.progress,
  });

  final Alignment alignment;
  final double thickness;
  final double? width;
  final Color? progressColor;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;

    const borderWidth = 2.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final realWidth = width ?? constraints.maxWidth;

        return SizedBox(
          width: realWidth,
          height: thickness,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                width: borderWidth,
                color: fuzzzyColors.surface,
              ),
            ),
            child: Align(
              alignment: alignment,
              child: SizedBox(
                width: realWidth * progress,
                height: thickness - borderWidth * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: progressColor ?? fuzzzyColors.surface,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
