import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Where a person stands: their trust chip on Home and their page.
enum PersonTrust {
  /// The invite is out; their reply has not come.
  waiting,

  /// Connected and the numbers were compared.
  checked,

  /// Connected; the numbers were not compared yet.
  notChecked,
}

/// The trust chip: "Waiting for reply" (neutral), "Checked" (success), "Not
/// checked" (warning). Words and an icon, never colour alone. Changing
/// [trust] swaps the chip in place ([ChipSwap]).
class PersonTrustChip extends StatelessWidget {
  const PersonTrustChip({super.key, required this.trust, this.qaId});

  final PersonTrust trust;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final (String label, FuzzzyStatusKind kind) = switch (trust) {
      PersonTrust.waiting => (
          localizations.chipWaitingForReply,
          FuzzzyStatusKind.neutral,
        ),
      PersonTrust.checked => (
          localizations.chipChecked,
          FuzzzyStatusKind.success,
        ),
      PersonTrust.notChecked => (
          localizations.chipNotChecked,
          FuzzzyStatusKind.warning,
        ),
    };

    return ChipSwap(
      child: FuzzzyStatusChip(
        key: ValueKey(trust),
        label: label,
        kind: kind,
        dot: true,
        qaId: qaId,
      ),
    );
  }
}

/// A person on Home: avatar, name, trust chip, one line and a time.
///
/// A waiting person's line is always "Then you can lock for each other".
/// [activity] is the last thing that happened ("You locked a message") when
/// the caller knows it; rows never show message text.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.name,
    required this.trust,
    required this.onTap,
    this.onLongPress,
    this.activity,
    this.time,
    this.highlight = false,
    required this.qaId,
  });

  final String name;
  final PersonTrust trust;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? activity;
  final String? time;

  /// Tints the row once ([RowTint]): it just changed.
  final bool highlight;
  final String qaId;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final localizations = context.fuzzzyInkLocalizations;
    final line = trust == PersonTrust.waiting
        ? localizations.personRowWaitingLine
        : activity;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    final time = this.time;

    return RowTint(
      play: highlight,
      child: Semantics(
        identifier: 'person.$qaId',
        button: true,
        container: true,
        child: FuzzzyTappable(
          key: Key('person.$qaId'),
          onTap: onTap,
          onLongPress: onLongPress,
          focusRingInset: true,
          builder: (context, active) => Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: EdgeInsets.symmetric(
              horizontal: space.l + space.xs,
              vertical: space.m + space.xs / 2,
            ),
            decoration: BoxDecoration(
              color: active ? colors.surface : null,
              border: Border(bottom: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                FuzzzyAvatar(
                  initials: initial.toUpperCase(),
                  size: FuzzzyAvatarSize.s44,
                ),
                SizedBox(width: space.m + space.xs / 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleS.copyWith(color: colors.ink),
                      ),
                      SizedBox(height: space.xs / 2),
                      Wrap(
                        spacing: space.s * 0.75,
                        runSpacing: space.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PersonTrustChip(trust: trust, qaId: qaId),
                          if (line != null)
                            Text(
                              line,
                              style: type.bodyS.copyWith(color: colors.inkMute),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (time != null) ...[
                  SizedBox(width: space.s),
                  Text(
                    time,
                    style: type.dataS.copyWith(color: colors.inkMute),
                  ),
                ],
                SizedBox(width: space.xs),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    size: context.fuzzzyIconSize.m,
                    color: colors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
