import 'dart:io';
import 'package:flutter/services.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:permission_handler/permission_handler.dart';

export 'user_file_location.dart';
export 'user_files_channel.dart';

/// Where the files the app produces end up so the user can find them
/// (T-0366).
///
/// The crypto core streams into the app's own chat folder
/// (`AppDocumentsDirectory/<chat name>/`); [publish] then moves the finished
/// file to its user-visible place and answers the path the message row keeps:
///
/// * Android — `Downloads/Fuzzzy Seal/<chat name>/`, through MediaStore on
///   API 29+ and the public Downloads folder (with the storage permission)
///   on API 24–28.
/// * iOS — the file stays in Documents, which `Info.plist` exposes to the
///   Files app as "On My iPhone › Fuzzzy Seal".
/// * Desktop — the file stays in the user's Documents folder.
class UserFileStore {
  UserFileStore({UserFilesChannel channel = const UserFilesChannel()})
      : _channel = channel;

  final UserFilesChannel _channel;

  /// Answers the public path of [outputPath]; the app's own copy is gone on
  /// Android once the move succeeded. Throws when the public place cannot be
  /// written, leaving [outputPath] in place.
  Future<String> publish({
    required String outputPath,
    required String chatName,
  }) async {
    if (!Platform.isAndroid) return outputPath;

    try {
      return await _channel.saveToDownloads(
        sourcePath: outputPath,
        chatName: chatName,
      );
    } on PlatformException catch (exception) {
      // API 24–28 asks for the legacy storage permission on first use.
      if (exception.code != 'permissionDenied') rethrow;
      final status = await Permission.storage.request();
      if (!status.isGranted) rethrow;
      return _channel.saveToDownloads(
        sourcePath: outputPath,
        chatName: chatName,
      );
    }
  }
}
