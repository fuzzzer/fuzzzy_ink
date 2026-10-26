import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

/// `.fuzz` files opened from other apps (DESIGN.md section 3, "or open a
/// .fuzz from another app"): the app is registered as their opener on
/// Android (a `VIEW` intent), iOS and macOS (the exported type
/// `com.fuzzzycore.ink.fuzz`).
///
/// Whatever arrives is only read, once: copied into a new incoming folder
/// ([UserFileStore.newIncomingPath]) and handed to Open as an
/// [OpenArrivedFile], which peeks at it (`PROTOCOL.md` §7.4) and spends
/// nothing until the person taps Open (a message or a person's file) or
/// Connect (a reply). The copy is wiped once Open used it or was left
/// ([UserFileStore.discardPickedCopy]), at erase and at every launch; a
/// lock keeps it for Open after the unlock (it is sealed).
/// Nothing is ever run or handed on, and nothing goes on the network.
///
/// - Android: a `content://` (or `file://`) URI, read by the native side
///   (`UserFiles.kt`), its name from the provider.
/// - iOS: a `file://` URL in the app's own `Documents/Inbox` or, on newer
///   systems, `tmp/<bundle id>-Inbox`, where the system put its copy; that
///   copy is deleted once taken.
/// - macOS: Finder hands the file to the app delegate, which queues it
///   ([opened]); the person's own file is left where it is.
class IncomingFiles {
  IncomingFiles({
    required UserFileStore userFileStore,
    required String documentsDirectoryPath,
    UserFilesChannel userFilesChannel = const UserFilesChannel(),
    MethodChannel channel = const MethodChannel(channelName),
    TargetPlatform? platform,
    String? systemTemporaryDirectoryPath,
  })  : _userFileStore = userFileStore,
        _documentsDirectoryPath = documentsDirectoryPath,
        _systemTemporaryDirectoryPath = systemTemporaryDirectoryPath ??
            (Platform.isIOS ? Directory.systemTemp.path : null),
        _userFilesChannel = userFilesChannel,
        _channel = channel,
        _platform = platform;

  static const channelName = 'com.fuzzzycore.ink/incoming';

  /// The name a file gets when its own name is unusable.
  static const fallbackName = 'incoming.fuzz';

  final UserFileStore _userFileStore;

  /// Where the incoming copies live.
  UserFileStore get userFileStore => _userFileStore;
  final String _documentsDirectoryPath;

  /// The app's own `tmp/` on iOS (`NSTemporaryDirectory()`).
  final String? _systemTemporaryDirectoryPath;
  final UserFilesChannel _userFilesChannel;
  final MethodChannel _channel;
  final TargetPlatform? _platform;
  final _opened = StreamController<Uri>.broadcast();

  /// Files the desktop handed over (macOS), in the order they came.
  Stream<Uri> get opened => _opened.stream;

  /// Whether [uri] names a file (not a Fuzzzy Ink link).
  static bool isFileUri(Uri uri) =>
      uri.scheme == 'file' || uri.scheme == 'content';

  /// Starts listening for files the desktop hands over and takes the ones
  /// that came before the app was ready.
  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await _takePending();
    });
    await _takePending();
  }

  Future<void> _takePending() async {
    List<String>? pending;
    try {
      pending = await _channel.invokeListMethod<String>('takePending');
    } on MissingPluginException {
      return; // Only macOS queues files natively.
    } on PlatformException catch (exception) {
      logger.w('INCOMING FILES: takePending failed: ${exception.code}');
      return;
    }
    for (final url in pending ?? const <String>[]) {
      final uri = Uri.tryParse(url);
      if (uri != null && isFileUri(uri)) _opened.add(uri);
    }
  }

  /// Copies the file [uri] names into a new incoming folder and answers the
  /// copy's path; null when it cannot be read (gone, a folder or a link,
  /// no permission).
  Future<String?> take(Uri uri) async {
    if (!isFileUri(uri)) return null;
    String? target;
    try {
      if (uri.scheme == 'content') {
        final name = await _userFilesChannel.incomingName(uri.toString());
        target = await _userFileStore.newIncomingPath(safeName(name));
        await _userFilesChannel.copyIncoming(uri.toString(), target);
        return target;
      }
      final sourcePath = uri.toFilePath();
      final type = await FileSystemEntity.type(sourcePath, followLinks: false);
      if (type != FileSystemEntityType.file) return null;
      target = await _userFileStore
          .newIncomingPath(safeName(path.basename(sourcePath)));
      await File(sourcePath).copy(target);
      if (_isOwnInboxCopy(sourcePath)) await _deleteQuietly(sourcePath);
      return target;
    } on Exception catch (error) {
      logger.w('INCOMING FILES: could not take a file: $error');
      if (target != null) await _userFileStore.wipe(target);
      return null;
    }
  }

  /// The base name of [name] without folders, control or direction
  /// characters; [fallbackName] when nothing usable is left.
  static String safeName(String? name) {
    final base = UserFileNames.forDisplay(
      UserFileNames.cleanPickedFileName(
        (name ?? '').split(RegExp(r'[\\/]')).last,
      ),
    ).replaceAll(':', '_').trim();
    if (base.isEmpty || base == '.' || base == '..') return fallbackName;
    return base;
  }

  /// iOS copies a file it hands over into `Documents/Inbox` or
  /// `tmp/<bundle id>-Inbox` (seen on iOS 26), both the app's own: that copy
  /// goes once taken. Nothing else is ever deleted.
  bool _isOwnInboxCopy(String sourcePath) {
    final platform = _platform ?? (Platform.isIOS ? TargetPlatform.iOS : null);
    if (platform != TargetPlatform.iOS) return false;
    final source = _canonical(sourcePath);
    final inbox = path.join(_documentsDirectoryPath, 'Inbox');
    if (path.isWithin(_canonical(inbox), source)) return true;
    final tmp = _systemTemporaryDirectoryPath;
    return tmp != null &&
        path.isWithin(_canonical(tmp), source) &&
        path.basename(path.dirname(source)).endsWith('-Inbox');
  }

  static String _canonical(String filePath) {
    try {
      return File(filePath).resolveSymbolicLinksSync();
    } on FileSystemException {
      return path.normalize(filePath);
    }
  }

  static Future<void> _deleteQuietly(String filePath) async {
    try {
      await File(filePath).delete();
    } on FileSystemException catch (error) {
      logger.w('INCOMING FILES: could not delete the Inbox copy: $error');
    }
  }

  void dispose() => _opened.close();
}
