import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final service = sl.get<PasswordStrengthService>();
    final strength = service.assess(password);

    final fuzzzyColors = context.fuzzzyColors;

    Color getLevelColor() {
      switch (strength.level) {
        case PasswordStrengthLevel.weak:
          return fuzzzyColors.destructiveText;
        case PasswordStrengthLevel.fair:
          return fuzzzyColors.warning;
        case PasswordStrengthLevel.good:
          return fuzzzyColors.info;
        case PasswordStrengthLevel.strong:
          return fuzzzyColors.success;
      }
    }

    final color = getLevelColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentContextLocalization.vaultPasswordStrength,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.fuzzzyColors.inkMute,
                  ),
            ),
            Text(
              '${strength.level.name.toUpperCase()} ${strength.score}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: strength.score / 100.0,
            backgroundColor: context.fuzzzyColors.surface,
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
