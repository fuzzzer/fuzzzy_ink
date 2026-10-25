import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Gives [filePath] to the system save dialog under [fileName] and toasts
/// the outcome; `true` once saved. The caller wipes its own plain copy.
Future<bool> saveFileForUser(
  BuildContext context, {
  required String filePath,
  required String fileName,
  required UserFileStore store,
}) async {
  final localizations = context.fuzzzyInkLocalizations;
  try {
    final saved = await DeviceFileInteractor.saveFile(
      filePath,
      fileName: fileName,
      store: store,
      dialogTitle: localizations.saveFile,
      context: context,
    );
    if (saved && context.mounted) {
      FuzzzyToast.show(context, message: localizations.fileSaved);
    }
    return saved;
  } catch (error) {
    logger.w('FILE HAND-OFF: could not save: $error');
    if (context.mounted) {
      FuzzzyToast.show(context, message: localizations.couldNotSaveFile);
    }
    return false;
  }
}

/// Opens the share sheet for [filePath]; toasts a failure.
Future<void> shareFileForUser(
  BuildContext context, {
  required String filePath,
  required UserFileStore store,
}) async {
  try {
    await DeviceFileInteractor.shareFile(
      filePath,
      store: store,
      context: context,
    );
  } catch (error) {
    logger.w('FILE HAND-OFF: could not share: $error');
    if (!context.mounted) return;
    FuzzzyToast.show(
      context,
      message: context.fuzzzyInkLocalizations.couldNotOpenFile,
    );
  }
}
