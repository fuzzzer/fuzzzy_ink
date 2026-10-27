import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:path/path.dart' as path;

/// The archive's file name: `fuzzzy_ink_archive_<date>.fuzz`.
String chatArchiveFileName() {
  final date = DateTime.now().toIso8601String().substring(0, 10);
  return 'fuzzzy_ink_archive_$date.$fuzzedFileIdentificator';
}

/// Where a sealed archive is written: on a computer the path the user picks
/// in the system save dialog; on Android and iOS a copy in the app's hand-off
/// folder, given to the system save dialog by [handChatArchiveToUser] and
/// wiped right after. Null when the user cancelled.
Future<String?> chooseChatArchiveOutput(String dialogTitle) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return sl.get<UserFileStore>().newHandoffPath(chatArchiveFileName());
  }
  return FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: chatArchiveFileName(),
  );
}

/// On a phone, gives the archive at [outputPath] to the system save dialog
/// and wipes the app's copy; on a computer it is already where the user
/// chose. True once the user has it; a failure is toasted.
Future<bool> handChatArchiveToUser(
  BuildContext context, {
  required String outputPath,
  required String dialogTitle,
}) async {
  if (!(Platform.isAndroid || Platform.isIOS)) return true;
  final store = sl.get<UserFileStore>();
  try {
    return await DeviceFileInteractor.saveFile(
      outputPath,
      fileName: path.basename(outputPath),
      store: store,
      dialogTitle: dialogTitle,
      context: context,
    );
  } catch (error) {
    logger.w('ARCHIVE EXPORT: could not save: $error');
    if (context.mounted) {
      FuzzzyToast.show(
        context,
        message: context.fuzzzyInkLocalizations.couldNotSaveFile,
      );
    }
    return false;
  } finally {
    await store.wipe(outputPath);
  }
}
