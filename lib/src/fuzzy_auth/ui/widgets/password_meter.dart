import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The redesign's strength meter (DESIGN.md section 4.1): four short bars,
/// one hint ("Tip: a few random words." … "Very hard to guess.") and the
/// level (Weak · Fair · Good · Strong). The level comes from the app's one
/// strength check ([PasswordStrengthService]); a new password must reach
/// Good. The level is said in words, never by colour alone.
class PasswordMeter extends StatelessWidget {
  const PasswordMeter({super.key, required this.password, this.qaId});

  final String password;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final level = password.isEmpty
        ? null
        : sl.get<PasswordStrengthService>().assess(password).level;
    final filled = level == null ? 0 : level.index + 1;
    final tint = switch (level) {
      null => colors.track,
      PasswordStrengthLevel.weak => colors.destructive,
      PasswordStrengthLevel.fair => colors.warning,
      PasswordStrengthLevel.good => colors.info,
      PasswordStrengthLevel.strong => colors.success,
    };
    final (String hint, String name) = switch (level) {
      null => (localizations.accessStrengthHintEmpty, ''),
      PasswordStrengthLevel.weak => (
          localizations.accessStrengthHintWeak,
          localizations.accessStrengthWeak,
        ),
      PasswordStrengthLevel.fair => (
          localizations.accessStrengthHintFair,
          localizations.accessStrengthFair,
        ),
      PasswordStrengthLevel.good => (
          localizations.accessStrengthHintGood,
          localizations.accessStrengthGood,
        ),
      PasswordStrengthLevel.strong => (
          localizations.accessStrengthHintStrong,
          localizations.accessStrengthStrong,
        ),
    };

    return Semantics(
      key: Key('meter.${qaId ?? 'password'}'),
      container: true,
      liveRegion: true,
      label: name.isEmpty ? hint : localizations.accessStrengthLabel(name),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) SizedBox(width: space.xs),
                Expanded(
                  child: AnimatedContainer(
                    duration: context.fuzzzyMotion.fast,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < filled ? tint : colors.track,
                      borderRadius:
                          BorderRadius.circular(context.fuzzzyRadius.s),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: space.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  hint,
                  style: context.fuzzzyTextStyles.bodyS
                      .copyWith(color: colors.inkMute),
                ),
              ),
              if (name.isNotEmpty) ...[
                SizedBox(width: space.s),
                Text(
                  name,
                  style: context.fuzzzyTextStyles.bodyS.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
