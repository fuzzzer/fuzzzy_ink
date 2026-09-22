import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class InvitedChatTile extends StatelessWidget {
  final String name;
  final void Function() onTap;
  final void Function() onLongPress;

  const InvitedChatTile({
    required this.name,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzySealLocalizations;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      color: fuzzzyColors.surface.withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Icon(
          Icons.hourglass_empty,
          size: 32,
          color: fuzzzyColors.warning,
        ),
        title: Text(
          name,
          style: fuzzzyTextStyles.body.copyWith(color: fuzzzyColors.ink),
        ),
        subtitle: Text(
          localizations.waitingForAcceptance,
          style: fuzzzyTextStyles.bodyS.copyWith(color: fuzzzyColors.ink),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 32,
          color: fuzzzyColors.inkMute,
        ),
      ),
    );
  }
}
