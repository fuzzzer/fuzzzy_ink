import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Shown when a different acceptance arrives for a chat that is already
/// connected: the clearest sign that someone else accepted the invitation.
/// Offers the safety number, the one way to find out who is on the other end.
Future<void> showPairingWarningDialog(
  BuildContext context, {
  required String chatName,
  required VoidCallback onCheckSafetyNumber,
}) {
  final localizations = context.fuzzzyInkLocalizations;

  return FuzzzyDialog.showBuilder<void>(
    context,
    builder: (dialogContext) => FuzzzyDialog(
      qaId: 'pairingWarning',
      title: localizations.pairingWarningTitle,
      content: Text(localizations.pairingWarningMessage(chatName)),
      actions: [
        FuzzzyButton(
          qaId: 'pairingWarning.close',
          label: localizations.close,
          variant: FuzzzyButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        FuzzzyButton(
          qaId: 'pairingWarning.checkSafetyNumber',
          label: localizations.verifySafetyNumberCta,
          icon: const Icon(Icons.shield_outlined),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onCheckSafetyNumber();
          },
        ),
      ],
    ),
  );
}
