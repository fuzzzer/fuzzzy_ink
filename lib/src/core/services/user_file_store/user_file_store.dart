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
    String? systemTemporaryDirectoryPath,
    TargetPlatform? platform,
    Future<void> Function()? clearPickerCache,
    BackupExclusion backupExclusion = const BackupExclusion(),
  })  : _supportDirectoryPath = supportDirectoryPath,
        _temporaryDirectoryPath = temporaryDirectoryPath,
        _documentsDirectoryPath = documentsDirectoryPath,
        // Only a real iPhone's own `tmp/` is ever swept unless a folder is
        // given: a test that pretends to be iOS never touches the host's.
        _systemTemporaryDirectoryPath = systemTemporaryDirectoryPath ??
            (Platform.isIOS ? Directory.systemTemp.path : null),
        _platform = platform,
        _clearPickerCache = clearPickerCache ?? _clearFilePickerCache,
        _backupExclusion = backupExclusion;

  final String _supportDirectoryPath;
  final String _temporaryDirectoryPath;
  final String _documentsDirectoryPath;

  /// The process's own temporary folder (`NSTemporaryDirectory()` on iOS,
  /// the app's `tmp/`): the iOS picker copies files there, not into
  /// [_temporaryDirectoryPath] (`Library/Caches`). Security review
  /// 2026-10-26.
  final String? _systemTemporaryDirectoryPath;
  final TargetPlatform? _platform;
  final Future<void> Function() _clearPickerCache;
  final BackupExclusion _backupExclusion;

  static const sealedFolderName = 'sealed_files';
  static const chatsFolderName = 'chats';
  static const basicsFolderName = 'basics';

  /// Also the only folder Android's FileProvider serves
  /// (`res/xml/user_file_paths.xml`).
  static const handoffFolderName = 'handoff';

  /// `.fuzz` files another app handed over ([IncomingFiles]), waiting for
  /// Open. They are sealed, so a lock leaves them: one that arrives as the
  /// app locks on return, or waits on Open's confirm screen when the app
  /// locks, is still there after the unlock (2026-10-26, seen live). They go
  /// once Open used or left them, at erase and at every launch.
  static const incomingFolderName = 'incoming';

  /// The old Basics output folder under the documents directory.
  static const legacyBasicsFolderName = 'Working Folder';

  /// Where the archive export keeps its plain JSON lines while it seals
  /// (`ChatArchiveRepository`, `PROTOCOL.md` §9.5).
  static final _archiveWorkingFile = RegExp(r'^chat_archive_.*\.jsonl$');

  int _handoffCounter = 0;
  final Set<String> _pendingWipes = {};

  /// Incoming files kept through a lock for Open after the unlock
  /// ([keepForUnlock]): [wipe] leaves them until [release].
  final Set<String> _keptForUnlock = {};
  AppLifecycleListener? _lifecycleListener;

  String get sealedRootPath =>
      path.join(_supportDirectoryPath, sealedFolderName);

  String get handoffRootPath =>
      path.join(_supportDirectoryPath, handoffFolderName);

  String get incomingRootPath =>
      path.join(_supportDirectoryPath, incomingFolderName);

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

  /// `<new incoming folder>/<fileName>`: where a `.fuzz` file another app
  /// handed over is copied ([incomingFolderName]).
  Future<String> newIncomingPath(String fileName) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_handoffCounter++}';
    final folder = await _ensureFolder(path.join(incomingRootPath, id));
    return path.join(folder, path.basename(fileName));
  }

  bool isIncoming(String filePath) => path.isWithin(incomingRootPath, filePath);

  /// The app locked while [filePath] (an incoming file) waited for Open: it
  /// stays, whoever asks to [wipe] it, until [release].
  void keepForUnlock(String filePath) {
    if (isIncoming(filePath)) _keptForUnlock.add(filePath);
  }

  /// Open has the incoming file again: [wipe] may take it.
  void release(String filePath) => _keptForUnlock.remove(filePath);

  /// Every incoming file (erase everything).
  Future<void> wipeIncoming() async {
    _keptForUnlock.clear();
    await _deleteQuietly(Directory(incomingRootPath));
  }

  /// Deletes the hand-off or incoming copy at [filePath] and its folder. A
  /// path outside those folders is never touched, nor an incoming file kept
  /// for the unlock.
  Future<void> wipe(String filePath) async {
    if (isIncoming(filePath)) {
      if (_keptForUnlock.contains(filePath)) return;
      return _deleteQuietly(Directory(path.dirname(filePath)));
    }
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

  /// The app's own temporary folders a picker copy can be in: the cache
  /// folder (Android's picker) and, on iOS, the process's `tmp/` (the
  /// document picker's `<bundle id>-Inbox`).
  List<String> get _pickerCopyRoots {
    final tmp = _systemTemporaryDirectoryPath;
    return [
      _temporaryDirectoryPath,
      if (_hostPlatform == TargetPlatform.iOS && tmp != null) tmp,
    ];
  }

  /// Whether [inputPath] is a copy a picker made inside the app (a phone);
  /// on a computer the picker hands over the user's own file.
  bool isPickedCopy(String inputPath) =>
      _isPhone &&
      _pickerCopyRoots.any((root) => path.isWithin(root, inputPath));

  /// A file the picker copied into the app to hand it over (Android, iOS) is
  /// deleted once it was used, or when the flow that picked it ends without
  /// using it; on a computer the picker hands over the user's own file,
  /// which is never deleted.
  Future<void> discardPickedCopy(String inputPath) async {
    // A file another app opened in this one was copied into the incoming
    // folder ([IncomingFiles]): that copy goes once used, on every platform.
    if (isHandoff(inputPath) || isIncoming(inputPath)) return wipe(inputPath);
    if (!isPickedCopy(inputPath)) return;
    await _deleteQuietly(File(inputPath));
  }

  /// When the app locks (security review 2026-10-26): every plain hand-off
  /// copy and every picker copy goes, as at launch. A page still showing a
  /// copy is behind the lock screen; it reads the file again only after a
  /// new unfuzz. Sealed `.fuzz` files are left: the incoming folder, and on
  /// iOS a `.fuzz` the system is handing over in the app's `tmp/` as it
  /// locks on return (gone at the next launch).
  Future<void> wipeAtLock() async {
    _pendingWipes.clear();
    await _deleteQuietly(Directory(handoffRootPath));
    await _wipePickerCopies(keepSealed: true);
  }

  /// At every launch, before anything is unfuzzed: every plain copy a
  /// previous run may have left — the hand-off folder, the archive export's
  /// working file, the picker's cache, Android's old share staging
  /// (`cache/user_files`, `cache/share_plus`) and, on a phone, the old Basics
  /// `Working Folder`. Never throws.
  Future<void> wipeTemporaryPlainCopies() async {
    await _deleteQuietly(Directory(handoffRootPath));
    await _deleteQuietly(Directory(incomingRootPath));

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

    await _wipePickerCopies();
    if (_hostPlatform == TargetPlatform.android) {
      for (final staging in ['user_files', 'share_plus']) {
        await _deleteQuietly(
          Directory(path.join(_temporaryDirectoryPath, staging)),
        );
      }
    }
    await _deleteQuietly(
      Directory(path.join(_documentsDirectoryPath, legacyBasicsFolderName)),
    );
  }

  /// The picker's copies on a phone: its own clean-up, Android's
  /// `cache/file_picker`, and on iOS everything in the app's `tmp/` — a
  /// folder private to the app that nothing else of the app writes to.
  ///
  /// With [keepSealed] (at lock) a `.fuzz` file in the iOS `tmp/` stays, and
  /// so the picker's own clean-up, which empties all of `tmp/` there, is not
  /// asked for on iOS.
  Future<void> _wipePickerCopies({bool keepSealed = false}) async {
    if (!_isPhone) return;
    final isIos = _hostPlatform == TargetPlatform.iOS;
    if (!(keepSealed && isIos)) {
      try {
        await _clearPickerCache();
      } catch (error) {
        logger.w('FILE STORE: could not clear the picker cache: $error');
      }
    }
    if (_hostPlatform == TargetPlatform.android) {
      await _deleteQuietly(
        Directory(path.join(_temporaryDirectoryPath, 'file_picker')),
      );
    }
    final tmpPath = _systemTemporaryDirectoryPath;
    if (_hostPlatform == TargetPlatform.iOS && tmpPath != null) {
      try {
        final tmp = Directory(tmpPath);
        if (await tmp.exists()) {
          await for (final entity in tmp.list()) {
            if (keepSealed && entity is Directory) {
              await _wipeAllButSealed(entity);
            } else if (!(keepSealed && _isSealed(entity.path))) {
              await _deleteQuietly(entity);
            }
          }
        }
      } catch (error) {
        logger.w('FILE STORE: could not sweep the iOS tmp folder: $error');
      }
    }
  }

  static bool _isSealed(String filePath) =>
      path.extension(filePath).toLowerCase() == '.$fuzzedFileIdentificator';

  /// Everything in [folder] but `.fuzz` files; the folder too once empty.
  static Future<void> _wipeAllButSealed(Directory folder) async {
    var kept = false;
    await for (final entity in folder.list()) {
      if (entity is Directory) {
        await _wipeAllButSealed(entity);
        if (await entity.exists()) kept = true;
      } else if (_isSealed(entity.path)) {
        kept = true;
      } else {
        await _deleteQuietly(entity);
      }
    }
    if (!kept) await _deleteQuietly(folder);
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
