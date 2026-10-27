import 'package:flutter/services.dart';

/// The Android side of handing a file to the user (`UserFiles.kt`): the
/// system save dialog and the share sheet, both by content URI from the
/// app's hand-off folder (`res/xml/user_file_paths.xml` exposes nothing
/// else); and reading a `.fuzz` file another app opened in this one
/// (`IncomingFiles`). Every call throws a [PlatformException] whose `code`
/// is `notFound`, `noHandler` or `failed`.
class UserFilesChannel {
  const UserFilesChannel();

  static const _channel = MethodChannel('com.fuzzzycore.ink/user_files');

  /// Shows the system save dialog (`ACTION_CREATE_DOCUMENT`) with
  /// [fileName] proposed and copies [path] to the place the user picked.
  /// `true` once written, `false` when the user backed out.
  Future<bool> saveAs(
    String path, {
    required String fileName,
    String? mimeType,
  }) async {
    final result = await _channel.invokeMethod<String>(
      'saveAs',
      {'path': path, 'fileName': fileName, 'mimeType': mimeType},
    );
    return result == 'saved';
  }

  /// Opens the share sheet for [path], which must be inside the hand-off
  /// folder.
  Future<void> shareFile(String path, {String? mimeType}) =>
      _channel.invokeMethod<void>(
        'shareFile',
        {'path': path, 'mimeType': mimeType},
      );

  /// The name the provider gives the file at content [uri], if any.
  Future<String?> incomingName(String uri) =>
      _channel.invokeMethod<String>('incomingName', {'uri': uri});

  /// Copies the file at content [uri] to [path], which must be inside the
  /// hand-off folder; only reads [uri].
  Future<void> copyIncoming(String uri, String path) =>
      _channel.invokeMethod<void>('copyIncoming', {'uri': uri, 'path': path});
}
