import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Copies a vault password through the copy guard: marked sensitive, cleared
/// after `CopyPolicy.vaultPasswordClearAfter`. Shown only while
/// `allowVaultPasswordCopy` is on.
class VaultPasswordCopyButton extends StatelessWidget {
  const VaultPasswordCopyButton({required this.password, super.key});

  /// The password to copy, read only when the button is pressed (the list
  /// opens the item then). Null or empty copies nothing.
  final FutureOr<String?> Function() password;

  Future<void> _copy(BuildContext context) async {
    final localizations = context.fuzzzyInkLocalizations;
    final text = await password();
    if (text == null || text.isEmpty || !context.mounted) return;
    await CopyGuard.copy(
      context,
      text: text,
      content: CopyContent.vaultPassword,
      copiedMessage: localizations.vaultPasswordCopiedClearsIn(
        CopyPolicy.vaultPasswordClearAfter.inSeconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = context.fuzzzyInkLocalizations.vaultCopyPassword;
    return IconButton(
      key: const Key('vault.copy_password'),
      tooltip: label,
      icon: Icon(
        Icons.copy,
        semanticLabel: label,
        color: context.fuzzzyColors.inkMute,
      ),
      onPressed: () => _copy(context),
    );
  }
}
