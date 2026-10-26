import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

export 'user_file_names.dart';
export 'user_files_channel.dart';

/// Where the app keeps files (owner, 2026-10-26: "transfer ownership of
/// unfuzzed files to user and we store only fuzzed ones").
///
/// The app's private storage holds sealed files only:
///
/// * `<support>/sealed_files/chats/<safe chat name> (<id>)/` — one folder per
///   chat ([UserFileNames.safeChatFolderName]): the `.fuzz` containers the
///   user sent, and the received containers the app keeps (their key sealed
///   in the message row, `PROTOCOL.md` §9.6). Deleting the chat deletes it.
/// * `<support>/sealed_files/basics/` — the password containers Basics made.
/// * `<support>/vault/` — the vault's own folder (`VaultFileDataSource`).
///
/// A plain file exists only for the moment it is used: unfuzzed into
/// `<support>/handoff/<one folder per use>/` to be shown in the app, given to
/// the system save dialog or the share sheet, and wiped right after
/// ([wipe], [wipeWhenBack]) and at every launch ([wipeTemporaryPlainCopies]).
/// Message rows store paths relative to `sealed_files`, so an iOS container
/// move between updates does not break them.
class UserFileStore {
  UserFileStore({
    required String supportDirectoryPath,
    required String temporaryDirectoryPath,
    required String documentsDirectoryPath,
    TargetPlatform? platform,
    Future<void> Function()? clearPickerCache,
    BackupExclusion backupExclusion = const BackupExclusion(),
  })  : _supportDirectoryPath = supportDirectoryPath,
        _temporaryDirectoryPath = temporaryDirectoryPath,
        _documentsDirectoryPath = documentsDirectoryPath,
        _platform = platform,
        _clearPickerCache = clearPickerCache ?? _clearFilePickerCache,
        _backupExclusion = backupExclusion;

  final String _supportDirectoryPath;
  final String _temporaryDirectoryPath;
  final String _documentsDirectoryPath;
  final TargetPlatform? _platform;
  final Future<void> Function() _clearPickerCache;
  final BackupExclusion _backupExclusion;

  static const sealedFolderName = 'sealed_files';
  static const chatsFolderName = 'chats';
  static const basicsFolderName = 'basics';

  /// Also the only folder Android's FileProvider serves
  /// (`res/xml/user_file_paths.xml`).
  static const handoffFolderName = 'handoff';

  /// The old Basics output folder under the documents directory.
  static const legacyBasicsFolderName = 'Working Folder';

  /// Where the archive export keeps its plain JSON lines while it seals
  /// (`ChatArchiveRepository`, `PROTOCOL.md` §9.5).
  static final _archiveWorkingFile = RegExp(r'^chat_archive_.*\.jsonl$');

  int _handoffCounter = 0;
  final Set<String> _pendingWipes = {};
  AppLifecycleListener? _lifecycleListener;

  String get sealedRootPath =>
      path.join(_supportDirectoryPath, sealedFolderName);

  String get handoffRootPath =>
      path.join(_supportDirectoryPath, handoffFolderName);

  TargetPlatform get _hostPlatform {
    if (_platform != null) return _platform;
    if (Platform.isAndroid) return TargetPlatform.android;
    if (Platform.isIOS) return TargetPlatform.iOS;
    if (Platform.isMacOS) return TargetPlatform.macOS;
    if (Platform.isWindows) return TargetPlatform.windows;
    return TargetPlatform.linux;
  }

  bool get _isPhone =>
      _hostPlatform == TargetPlatform.android ||
      _hostPlatform == TargetPlatform.iOS;

  // -------------------------------------------------------------------------
  // Sealed files
  // -------------------------------------------------------------------------

  /// The chat's folder, created on first use.
  Future<String> chatFolder({
    required String chatName,
    required String chatId,
  }) =>
      _ensureFolder(_chatFolderPath(chatName: chatName, chatId: chatId));

  /// The Basics folder, created on first use.
  Future<String> basicsFolder() =>
      _ensureFolder(path.join(sealedRootPath, basicsFolderName));

  /// The password containers in the Basics folder, newest first.
  Future<List<File>> basicsFiles() async {
    final folder = Directory(path.join(sealedRootPath, basicsFolderName));
    if (!await folder.exists()) return const [];
    final files = await folder
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => !file.path.endsWith('.part'))
        .toList();
    final modified = {
      for (final file in files) file.path: await file.lastModified(),
    };
    return files
      ..sort((a, b) => modified[b.path]!.compareTo(modified[a.path]!));
  }

  /// Deletes one container from the Basics folder; a path elsewhere is never
  /// touched.
  Future<void> deleteBasicsFile(String filePath) async {
    final basics = path.join(sealedRootPath, basicsFolderName);
    if (!path.isWithin(basics, filePath)) return;
    await _deleteQuietly(File(filePath));
  }

  /// What a message row keeps for [absolutePath]: the path relative to the
  /// sealed folder.
  String storedPathOf(String absolutePath) =>
      path.relative(absolutePath, from: sealedRootPath);

  /// Inverse of [storedPathOf]; an absolute path is returned as it is.
  String resolve(String storedPath) => path.isAbsolute(storedPath)
      ? storedPath
      : path.join(sealedRootPath, storedPath);

  /// Deletes the chat's folder: the one its current name gives, and the
  /// folder of every file row in [storedPaths] (a renamed chat keeps the
  /// folder of its old name). Nothing outside `sealed_files/chats` is
  /// touched.
  Future<void> deleteChatFiles({
    required String chatName,
    required String chatId,
    Iterable<String> storedPaths = const [],
  }) async {
    final chatsRoot = path.join(sealedRootPath, chatsFolderName);
    final folders = {
      _chatFolderPath(chatName: chatName, chatId: chatId),
      for (final storedPath in storedPaths) path.dirname(resolve(storedPath)),
    }.where((folder) => path.isWithin(chatsRoot, folder));

    for (final folder in folders) {
      await _deleteQuietly(Directory(folder));
    }
  }

  String _chatFolderPath({required String chatName, required String chatId}) =>
      path.join(
        sealedRootPath,
        chatsFolderName,
        UserFileNames.safeChatFolderName(chatName: chatName, chatId: chatId),
      );

  Future<String> _ensureFolder(String folderPath) async {
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
      await _backupExclusion.exclude(folder.path);
    }
    return folder.path;
  }

  // -------------------------------------------------------------------------
  // Plain copies (hand-off)
  // -------------------------------------------------------------------------

  /// A new empty folder for one use of one plain file, so the file keeps its
  /// own name for the viewer, the save dialog and the share sheet.
  Future<String> newHandoffFolder() {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_handoffCounter++}';
    return _ensureFolder(path.join(handoffRootPath, id));
  }

  /// `<new hand-off folder>/<fileName>`; only the base name of [fileName]
  /// is used.
  Future<String> newHandoffPath(String fileName) async =>
      path.join(await newHandoffFolder(), path.basename(fileName));

  bool isHandoff(String filePath) => path.isWithin(handoffRootPath, filePath);

  /// Deletes the hand-off copy at [filePath] and its folder. A path outside
  /// the hand-off folder is never touched.
  Future<void> wipe(String filePath) async {
    if (!isHandoff(filePath)) return;
    _pendingWipes.remove(filePath);
    final folder = path.dirname(filePath);
    if (path.equals(folder, handoffRootPath)) {
      await _deleteQuietly(File(filePath));
    } else {
      await _deleteQuietly(Directory(folder));
    }
  }

  /// For a copy another app may still be reading (Android's share sheet
  /// returns before the target has read it): wiped when the app is back in
  /// front, and at the next launch at the latest.
  void wipeWhenBack(String filePath) {
    if (!isHandoff(filePath)) return;
    _pendingWipes.add(filePath);
    _lifecycleListener ??= AppLifecycleListener(onResume: wipePending);
  }

  /// Wipes everything [wipeWhenBack] holds.
  Future<void> wipePending() async {
    for (final filePath in _pendingWipes.toList()) {
      await wipe(filePath);
    }
  }

  /// A file the picker copied into the app's cache to hand it over (Android,
  /// iOS), or a hand-off copy, is deleted once it was used; on a computer the
  /// picker hands over the user's own file, which is never deleted.
  Future<void> discardPickedCopy(String inputPath) async {
    // A file another app opened in this one was copied into the hand-off
    // folder ([IncomingFiles]): that copy goes once used, on every platform.
    if (isHandoff(inputPath)) return wipe(inputPath);
    if (!_isPhone) return;
    if (!path.isWithin(_temporaryDirectoryPath, inputPath)) return;
    await _deleteQuietly(File(inputPath));
  }

  /// At every launch, before anything is unfuzzed: every plain copy a
  /// previous run may have left — the hand-off folder, the archive export's
  /// working file, the picker's cache, Android's old share staging
  /// (`cache/user_files`, `cache/share_plus`) and, on a phone, the old Basics
  /// `Working Folder`. Never throws.
  Future<void> wipeTemporaryPlainCopies() async {
    await _deleteQuietly(Directory(handoffRootPath));

    try {
      final support = Directory(_supportDirectoryPath);
      if (await support.exists()) {
        await for (final entity in support.list()) {
          if (entity is File &&
              _archiveWorkingFile.hasMatch(path.basename(entity.path))) {
            await _deleteQuietly(entity);
          }
        }
      }
    } catch (error) {
      logger.w('FILE STORE: could not sweep archive working files: $error');
    }

    if (!_isPhone) return;

    try {
      await _clearPickerCache();
    } catch (error) {
      logger.w('FILE STORE: could not clear the picker cache: $error');
    }
    if (_hostPlatform == TargetPlatform.android) {
      for (final staging in ['file_picker', 'user_files', 'share_plus']) {
        await _deleteQuietly(
          Directory(path.join(_temporaryDirectoryPath, staging)),
        );
      }
    }
    await _deleteQuietly(
      Directory(path.join(_documentsDirectoryPath, legacyBasicsFolderName)),
    );
  }

  static Future<void> _clearFilePickerCache() async {
    await FilePicker.platform.clearTemporaryFiles();
  }

  static Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } catch (error) {
      logger.w('FILE STORE: could not delete ${entity.path}: $error');
    }
  }
}
