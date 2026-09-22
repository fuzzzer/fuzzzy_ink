import 'dart:io';

import 'package:path/path.dart' as path;

/// What a file bubble prints instead of a path (T-0366): the file's name and
/// where the user finds it, e.g. `Downloads › Fuzzzy Seal › Fz bot`.
class UserFileLocation {
  const UserFileLocation({
    required this.fileName,
    required this.folderLine,
  });

  /// [filePath] is a file row's `encryptedMessage`. The line is rooted at the
  /// folder the user knows — the public Downloads folder on Android, the
  /// Documents folder on desktop, the Files app's "On My iPhone" on iOS — or
  /// at "App storage" for a row from before files were public. An app-private
  /// path such as `/data/user/0/...` is never printed.
  factory UserFileLocation.of(String filePath, {bool? isIOS}) {
    final segments = path.split(filePath);
    final fileName = segments.isEmpty ? '' : segments.last;
    final folders = segments.length > 1
        ? segments.sublist(0, segments.length - 1)
        : const <String>[];

    for (final root in _roots) {
      final rootIndex = folders.lastIndexOf(root.folder);
      if (rootIndex == -1) continue;
      final label = root.folder == _documents && (isIOS ?? Platform.isIOS)
          ? _iosDocumentsLabel
          : root.label;
      return UserFileLocation(
        fileName: fileName,
        folderLine: [label, ...folders.sublist(rootIndex + 1)].join(separator),
      );
    }

    return UserFileLocation(
      fileName: fileName,
      folderLine: folders.isEmpty ? '' : folders.last,
    );
  }

  final String fileName;
  final String folderLine;

  static const separator = ' › ';

  static const _documents = 'Documents';
  static const _iosDocumentsLabel = 'On My iPhone › Fuzzzy Seal';

  /// Checked in order; `Download` is Android's public folder, `app_flutter`
  /// the app's private documents directory on Android.
  static const _roots = [
    (folder: 'Download', label: 'Downloads'),
    (folder: _documents, label: _documents),
    (folder: 'app_flutter', label: 'App storage'),
  ];

  /// Some Android content providers (WhatsApp's media, as seen on the
  /// owner's Samsung) name a picked file `null-<name>` when their own prefix
  /// is missing. The artefact is not the user's and is dropped from the name
  /// the fuzzed file gets.
  static String cleanPickedFileName(String fileName) {
    const pickerArtefact = 'null-';
    return fileName.startsWith(pickerArtefact)
        ? fileName.substring(pickerArtefact.length)
        : fileName;
  }
}
