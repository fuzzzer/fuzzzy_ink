import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// [DeviceFileInteractor.openFile] refused a file the default handler would
/// run, install or follow ([UserFileNames.isRiskyToOpen]); the caller offers
/// [DeviceFileInteractor.revealFile] instead.
class RiskyFileOpenRefused implements Exception {
  const RiskyFileOpenRefused(this.filePath);

  final String filePath;

  @override
  String toString() =>
      'Not opened: ${UserFileNames.forDisplay(path.basename(filePath))} could '
      'run a program. Use Show in folder instead.';
}

class DeviceFileInteractor {
  static const _userFiles = UserFilesChannel();

  /// A `.fuzz` container has no registered type; it is shared and opened as
  /// a plain binary so every target app accepts it. Other files carry the
  /// type their extension implies (share_plus / Android resolve it).
  static String? explicitMimeType(String filePath) =>
      filePath.endsWith('.$fuzzedFileIdentificator')
          ? 'application/octet-stream'
          : null;

  static Future<void> shareFile(
    String filePath, {
    BuildContext? context,
  }) async {
    if (Platform.isAndroid) {
      // By content URI, so a file this app owns in Downloads (API 29) and a
      // row from before T-0366 both reach the share sheet.
      await _userFiles.shareFile(
        filePath,
        mimeType: explicitMimeType(filePath),
      );
      return;
    }

    final file = File(filePath);
    final fileExists = await file.exists();
    if (!fileExists) {
      throw FileSystemException('File does not exist', filePath);
    }

    final xFile = XFile(filePath, mimeType: explicitMimeType(filePath));

    if (context != null) {
      // ignore: use_build_context_synchronously
      await ShareHelper.shareXFiles([xFile], context: context);
    } else {
      await Share.shareXFiles([xFile]);
    }
  }

  /// Hands the file to the system's default app. A file that app would run,
  /// install or follow — a program, installer, script or shortcut, whatever
  /// its name pretends — is refused with [RiskyFileOpenRefused] before
  /// anything is launched: a received file's name is the sender's choice.
  static Future<void> openFile(String filePath) async {
    if (UserFileNames.isRiskyToOpen(path.basename(filePath))) {
      throw RiskyFileOpenRefused(filePath);
    }

    if (Platform.isAndroid) {
      await _userFiles.openFile(
        filePath,
        mimeType: explicitMimeType(filePath),
      );
      return;
    }

    final file = File(filePath);
    final fileExists = await file.exists();
    if (!fileExists) {
      throw FileSystemException('File does not exist', filePath);
    }

    final uri = Uri.file(filePath);

    final isUrlLaunched = await launchUrl(uri);
    if (!isUrlLaunched) {
      throw Exception('Could not open file: $filePath');
    }
  }

  ///Only desktop platforms have a file manager that can select an arbitrary
  ///file (the vault's temporary files rely on this). The chat's own files
  ///are public on mobile too, so [revealFile] works there as well.
  static bool get canRevealFile =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Shows where the file lives: desktop selects it in the file manager,
  /// Android opens its `Downloads/Fuzzzy Ink/<chat>` folder in the system
  /// file manager, iOS opens the Files app on the app's folder. When that
  /// place cannot be opened (a row from before T-0366, no file manager) the
  /// share sheet is the fallback; a missing file throws.
  static Future<void> revealFile(
    String filePath, {
    BuildContext? context,
  }) async {
    if (Platform.isAndroid) {
      try {
        await _userFiles.showInFiles(filePath);
      } on PlatformException {
        // ignore: use_build_context_synchronously
        await shareFile(filePath, context: context);
      }
      return;
    }

    final file = File(filePath);
    final fileExists = await file.exists();

    if (!fileExists) {
      throw FileSystemException('File does not exist', filePath);
    }

    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      final folderPath = File(filePath).parent.path;

      final fileManagers = [
        ['nautilus', '--select', filePath],
        ['dolphin', '--select', filePath],
        ['nemo', folderPath],
        ['xdg-open', folderPath],
      ];

      for (final command in fileManagers) {
        try {
          final result = await Process.run(command[0], command.sublist(1));
          if (result.exitCode == 0) return;
        } catch (_) {}
      }

      throw Exception('Could not open file manager on Linux.');
    } else if (Platform.isIOS) {
      // The Files app opens the app's Documents folder in place
      // (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace).
      final filesAppUri =
          Uri(scheme: 'shareddocuments', path: file.parent.path);
      final opened = await launchUrl(filesAppUri);
      if (!opened) {
        // ignore: use_build_context_synchronously
        await shareFile(filePath, context: context);
      }
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
