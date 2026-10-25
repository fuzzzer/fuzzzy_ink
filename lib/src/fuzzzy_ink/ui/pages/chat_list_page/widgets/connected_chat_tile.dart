import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class ConnectedChatTile extends StatelessWidget {
  final String name;

  /// Shows a "not verified" mark until the safety number is verified.
  final bool isVerified;
  final void Function() onTap;
  final void Function() onLongPress;

  const ConnectedChatTile({
    required this.name,
    required this.isVerified,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzyInkLocalizations;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      color: fuzzzyColors.surface,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Icon(
          Icons.lock,
          size: 32,
          color: fuzzzyColors.success,
        ),
        title: Text(
          name,
          style: fuzzzyTextStyles.body.copyWith(color: fuzzzyColors.ink),
        ),
        subtitle: isVerified
            ? Text(
                localizations.tapToViewChat,
                style: fuzzzyTextStyles.bodyS.copyWith(color: fuzzzyColors.ink),
              )
            : Align(
                alignment: AlignmentDirectional.centerStart,
                child: FuzzzyStatusChip(
                  key: const ValueKey('chat_tile_not_verified'),
                  label: localizations.notVerified,
                  kind: FuzzzyStatusKind.warning,
                  dot: true,
                ),
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
