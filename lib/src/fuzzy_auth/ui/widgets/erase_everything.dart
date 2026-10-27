import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Erase everything and start over", after an explicit confirmation: keys,
/// people, history, My safe and settings go and the first run starts again.
/// The way out with neither the password nor the recovery key, and for a
/// device whose secure storage holds keys this build cannot read (leftovers
/// of an earlier build). [qaId] prefixes the dialog's keys.
Future<void> confirmAndEraseEverything(
  BuildContext context, {
  required String qaId,
}) async {
  final localizations = context.fuzzzyInkLocalizations;
  final erase = await FuzzzyDialog.show<bool>(
    context,
    title: localizations.eraseTitle,
    qaId: '$qaId.eraseConfirm',
    content: Text(
      localizations.eraseMessage,
      style: context.fuzzzyTextStyles.body
          .copyWith(color: context.fuzzzyColors.ink),
    ),
    actions: [
      FuzzzyButton(
        label: localizations.cancel,
        variant: FuzzzyButtonVariant.secondary,
        qaId: '$qaId.eraseCancel',
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
      ),
      FuzzzyButton(
        label: localizations.eraseConfirm,
        variant: FuzzzyButtonVariant.destructive,
        qaId: '$qaId.eraseYes',
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
      ),
    ],
  );
  if (!(erase ?? false) || !context.mounted) return;
  final eraseRes = await context.read<FuzzyAuthStore>().eraseEverything();
  if (eraseRes is CryptoCoreFailure<void> && context.mounted) {
    showInkToast(
      context,
      message: localizations.unknownError,
      kind: FuzzzyToastKind.error,
    );
  }
}
