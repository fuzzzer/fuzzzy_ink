import 'package:flutter/services.dart';

/// The Android side of the user-visible file store (`UserFiles.kt`): files
/// land in `Downloads/Fuzzzy Ink/<chat name>/` through MediaStore and are
/// opened, shown and shared from there by content URI (T-0366). Every call
/// throws a [PlatformException] whose `code` is `permissionDenied`,
/// `notFound`, `noHandler` or `failed`.
class UserFilesChannel {
  const UserFilesChannel();

  static const _channel =
      MethodChannel('com.fuzzzycore.ink/user_files');

  /// Moves [sourcePath] into `Downloads/Fuzzzy Ink/[chatName]/` and answers
  /// the public path the message row keeps.
  Future<String> saveToDownloads({
    required String sourcePath,
    required String chatName,
  }) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'saveToDownloads',
      {'sourcePath': sourcePath, 'chatName': chatName},
    );
    return result!['path']! as String;
  }

  /// Opens the folder of [path] in the system file manager (the Downloads
  /// app when the folder itself cannot be opened).
  Future<void> showInFiles(String path) =>
      _channel.invokeMethod<void>('showInFiles', {'path': path});

  Future<void> openFile(String path, {String? mimeType}) =>
      _channel.invokeMethod<void>(
        'openFile',
        {'path': path, 'mimeType': mimeType},
      );

  Future<void> shareFile(String path, {String? mimeType}) =>
      _channel.invokeMethod<void>(
        'shareFile',
        {'path': path, 'mimeType': mimeType},
      );
}
