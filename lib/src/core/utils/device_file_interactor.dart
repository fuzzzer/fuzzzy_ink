import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

/// Hands a file to the user: the system save dialog or the share sheet.
/// The app never opens a file in another app and never shows its folder —
/// its own folders are private and hold sealed files only (`UserFileStore`).
class DeviceFileInteractor {
  static const _userFiles = UserFilesChannel();

  /// A `.fuzz` container has no registered type; it is shared and saved as a
  /// plain binary so every target app accepts it. Other files carry the type
  /// their extension implies (share_plus / Android resolve it).
  static String? explicitMimeType(String filePath) =>
      filePath.endsWith('.$fuzzedFileIdentificator')
          ? 'application/octet-stream'
          : null;

  /// Opens the share sheet for [filePath]. On Android only the hand-off
  /// folder can be shared (the FileProvider serves nothing else), so a file
  /// elsewhere is first copied there; that copy is wiped when the app is back
  /// in front. The caller's own file is left to the caller.
  static Future<void> shareFile(
    String filePath, {
    required UserFileStore store,
    BuildContext? context,
  }) async {
    if (!await File(filePath).exists()) {
      throw FileSystemException('File does not exist', filePath);
    }

    if (Platform.isAndroid) {
      var shared = filePath;
      if (!store.isHandoff(filePath)) {
        shared = await store.newHandoffPath(path.basename(filePath));
        await File(filePath).copy(shared);
        store.wipeWhenBack(shared);
      }
      await _userFiles.shareFile(shared, mimeType: explicitMimeType(shared));
      return;
    }

    final xFile = XFile(filePath, mimeType: explicitMimeType(filePath));
    if (context != null && context.mounted) {
      await ShareHelper.shareXFiles([xFile], context: context);
    } else {
      await Share.shareXFiles([xFile]);
    }
  }

  /// Gives [filePath] to the user under [fileName] through the system's own
  /// save dialog: Android's document picker, a computer's save panel; on
  /// iOS the share sheet, whose "Save to Files" is the platform's save
  /// dialog. `false` when the user backed out.
  static Future<bool> saveFile(
    String filePath, {
    required String fileName,
    required UserFileStore store,
    String? dialogTitle,
    BuildContext? context,
  }) async {
    if (!await File(filePath).exists()) {
      throw FileSystemException('File does not exist', filePath);
    }

    if (Platform.isAndroid) {
      return _userFiles.saveAs(
        filePath,
        fileName: fileName,
        mimeType: explicitMimeType(fileName),
      );
    }

    if (Platform.isIOS) {
      // ignore: use_build_context_synchronously
      await shareFile(filePath, store: store, context: context);
      return true;
    }

    final target = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: _desktopFileName(fileName),
    );
    if (target == null) return false;
    if (!path.equals(target, filePath)) {
      // The save panel already asked before replacing an existing file.
      await File(filePath).copy(target);
    }
    return true;
  }

  /// A name every desktop save panel accepts (Windows refuses `<>:"/\|?*`).
  static String _desktopFileName(String fileName) {
    final cleaned = UserFileNames.forDisplay(path.basename(fileName))
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();
    return cleaned.isEmpty ? 'file' : cleaned;
  }
}
