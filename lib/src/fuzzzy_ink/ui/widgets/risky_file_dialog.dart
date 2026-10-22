import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Shown when "Open" refused a received file that could run a program
/// ([RiskyFileOpenRefused]): says why, and offers the file's folder instead,
/// where the user can still open it on purpose.
Future<void> showRiskyFileDialog(
  BuildContext context, {
  required String fileName,
  required VoidCallback onShowInFolder,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      final localizations = context.fuzzzyInkLocalizations;

      return AlertDialog(
        title: Text(localizations.riskyFileNotOpenedTitle),
        content: Text(
          localizations.riskyFileNotOpenedMessage(
            UserFileNames.forDisplay(fileName),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('riskyFileDialog.cancel'),
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: context.fuzzzyColors.focus,
            ),
            child: Text(localizations.cancel),
          ),
          TextButton(
            key: const ValueKey('riskyFileDialog.showInFolder'),
            onPressed: () {
              Navigator.of(context).pop();
              onShowInFolder();
            },
            style: TextButton.styleFrom(
              foregroundColor: context.fuzzzyColors.focus,
            ),
            child: Text(localizations.showInFolder),
          ),
        ],
      );
    },
  );
}
