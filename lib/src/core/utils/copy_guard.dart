import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class CopyGuard {
  static Future<void> copyPlaintext({
    required BuildContext context,
    required String textToCopy,
  }) async {
    final prefs = sl.get<PreferencesService>();
    final localizations = context.fuzzzySealLocalizations;

    if (prefs.copySecurityLevel == CopySecurityLevel.strict) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(localizations.securityWarning),
            content: Text(
              localizations
                  .areYouSureYouWantToCopyUnencryptedDataToYourClipboardThisCouldCompromiseYourSecureChat,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: context.fuzzzyColors.focus,
                ),
                child: Text(localizations.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: context.fuzzzyColors.destructiveText,
                ),
                child: Text(localizations.copy),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;
    }

    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (!context.mounted) return;
    FuzzzyToast.show(context, message: localizations.copiedToTheClipboard);
  }
}
