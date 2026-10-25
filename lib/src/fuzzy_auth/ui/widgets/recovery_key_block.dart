import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A recovery key as the redesign shows it: its groups of four in two lines,
/// mono, inside a dashed box, never selectable or copyable, with the
/// "No copy · no screenshots" tag under it. [actions] (Print, Save as file)
/// sit below. The screen around it must be a [SensitiveScreen].
class RecoveryKeyBlock extends StatelessWidget {
  const RecoveryKeyBlock({
    super.key,
    required this.recoveryKey,
    this.actions,
    this.qaId,
  });

  /// As the core gives it ("K7QF 3MZD …" or "K7QF-3MZD-…").
  final String recoveryKey;
  final Widget? actions;
  final String? qaId;

  /// The key's groups: split on spaces or dashes, else every four characters.
  static List<String> groupsOf(String key) {
    final parts =
        key.trim().split(RegExp(r'[\s-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length > 1) return parts;
    final flat = parts.isEmpty ? '' : parts.single;
    return [
      for (var i = 0; i < flat.length; i += 4)
        flat.substring(i, i + 4 > flat.length ? flat.length : i + 4),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final radius = context.fuzzzyRadius.l;
    final groups = groupsOf(recoveryKey);
    final half = (groups.length / 2).ceil();
    final lines = [
      groups.take(half).join(' '),
      if (groups.length > half) groups.skip(half).join(' '),
    ];
    final actions = this.actions;

    return Column(
      key: qaId == null ? null : Key('recovery_key.$qaId'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomPaint(
          painter: FuzzzyDashedRRectPainter(
            color: colors.lineStrong,
            radius: radius,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: space.l + 2,
              horizontal: space.m,
            ),
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(radius),
            ),
            // Plain Text: never selectable, so never copyable.
            child: Column(
              children: [
                for (final line in lines)
                  Text(
                    line,
                    textAlign: TextAlign.center,
                    style: context.fuzzzyTextStyles.dataL.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      wordSpacing: 6,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: space.m),
        const Center(child: KeyTag()),
        if (actions != null) ...[SizedBox(height: space.m), actions],
      ],
    );
  }
}
