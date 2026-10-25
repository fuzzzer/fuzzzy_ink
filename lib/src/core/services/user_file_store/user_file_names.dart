import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// The rules for file and folder names the app did not choose itself: a
/// received file's name is the sender's (`PROTOCOL.md` §7.3 only makes it a
/// bare name), so it is untrusted when it is shown and stored
/// (`THREAT_MODEL.md` R14, R15).
abstract final class UserFileNames {
  /// Unicode direction controls (LRE, RLE, PDF, LRO, RLO, LRI, RLI, FSI,
  /// PDI, LRM, RLM, ALM): `invoice<RLO>fdp.exe` would read as `invoiceexe.pdf`.
  static final _bidiControls =
      RegExp(r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]');

  /// C0 and C1 control characters.
  static final _controls = RegExp(r'[\x00-\x1F\x7F-\x9F]');

  /// Characters that render as nothing (soft hyphen, zero-width space,
  /// joiners, word joiner, invisible operators, byte-order mark).
  static final _invisibles =
      RegExp(r'[\u00AD\u200B-\u200D\u2060-\u2064\uFEFF]');

  /// The text to show for [name]: direction controls and control characters
  /// removed, so what is read is the order the characters really have.
  static String forDisplay(String name) =>
      name.replaceAll(_bidiControls, '').replaceAll(_controls, '');

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

  // -------------------------------------------------------------------------
  // Storing
  // -------------------------------------------------------------------------

  static const _maxChatFolderNameLength = 60;
  static const _chatIdSuffixLength = 8;
  static const _fallbackChatFolderName = 'Chat';

  /// Device names Windows reserves, with or without an extension.
  static final _windowsReservedName = RegExp(
    r'^(con|prn|aux|nul|conin\$|conout\$|com[0-9¹²³]|lpt[0-9¹²³])$',
    caseSensitive: false,
  );

  /// [chatName] as one folder name every platform accepts, followed by the
  /// first [_chatIdSuffixLength] characters of [chatId] in brackets, e.g.
  /// `Bob (6f1e9b2c)`. Direction, invisible and control characters, path
  /// separators and `<>:"|?*` go; leading and trailing dots and spaces go
  /// (so `.` and `..` are gone too); a Windows device name (`CON`, `nul.txt`)
  /// gets a `_` after it; at
  /// most [_maxChatFolderNameLength] characters; `Chat` when nothing is left.
  /// The chat id suffix keeps two chats apart even when their names differ
  /// only in case or clean to the same text.
  static String safeChatFolderName({
    required String chatName,
    required String chatId,
  }) {
    var name = _withoutHiddenCharacters(chatName)
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    name = _trimDotsAndSpaces(name);

    final runes = name.runes.toList();
    if (runes.length > _maxChatFolderNameLength) {
      name = _trimDotsAndSpaces(
        String.fromCharCodes(runes.take(_maxChatFolderNameLength)),
      );
    }

    final dot = name.indexOf('.');
    final stem = dot == -1 ? name : name.substring(0, dot);
    if (_windowsReservedName.hasMatch(stem.trim())) {
      name = dot == -1 ? '${name}_' : '${stem}_${name.substring(dot)}';
    }
    if (name.isEmpty) name = _fallbackChatFolderName;

    final idCharacters =
        chatId.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final suffix = idCharacters.length <= _chatIdSuffixLength
        ? idCharacters
        : idCharacters.substring(0, _chatIdSuffixLength);
    return suffix.isEmpty ? name : '$name ($suffix)';
  }

  static String _withoutHiddenCharacters(String name) => name
      .replaceAll(_bidiControls, '')
      .replaceAll(_controls, '')
      .replaceAll(_invisibles, '');

  static String _trimDotsAndSpaces(String name) =>
      name.replaceAll(RegExp(r'^[\s.]+|[\s.]+$'), '');

  static const _partSuffix = '.part';
  static const _maxNameBytes = 255;
  static const _maxNumber = 9999;

  /// [desiredPath] when nothing is there yet, otherwise the first free
  /// `name (1).ext`, `name (2).ext`, … in the same folder — never an existing
  /// file. "Free" also means no `<name>.part`: the core writes there first
  /// and truncates whatever it finds, and a running job's `.part` reserves
  /// its name. A `.fuzz` keeps its inner extension (`report (1).pdf.fuzz`).
  ///
  /// The choice is made before the job runs and the core renames onto it at
  /// the end, so a file another program creates under the same name *while*
  /// the job runs is still replaced; the app's own jobs are kept apart by the
  /// `.part` rule.
  static Future<String> uniqueOutputPath(String desiredPath) async {
    if (await _isFree(desiredPath)) return desiredPath;

    final folder = path.dirname(desiredPath);
    final (:stem, :extension) = _splitForNumbering(path.basename(desiredPath));
    for (var number = 1; number <= _maxNumber; number++) {
      final candidate =
          path.join(folder, _fitName(stem, ' ($number)', extension));
      if (await _isFree(candidate)) return candidate;
    }
    throw FileSystemException('No free file name', desiredPath);
  }

  static Future<bool> _isFree(String filePath) async {
    for (final candidate in [filePath, '$filePath$_partSuffix']) {
      final type = await FileSystemEntity.type(candidate, followLinks: false);
      if (type != FileSystemEntityType.notFound) return false;
    }
    return true;
  }

  static ({String stem, String extension}) _splitForNumbering(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return (stem: name, extension: '');
    var stem = name.substring(0, dot);
    var extension = name.substring(dot);
    final innerDot = stem.lastIndexOf('.');
    if (extension == '.fuzz' && innerDot > 0) {
      extension = '${stem.substring(innerDot)}$extension';
      stem = stem.substring(0, innerDot);
    }
    return (stem: stem, extension: extension);
  }

  /// `stem + number + extension`, the stem shortened until the name and its
  /// `.part` still fit the 255-byte name limit of every desktop file system.
  static String _fitName(String stem, String number, String extension) {
    final runes = stem.runes.toList();
    var length = runes.length;
    String nameOf(int length) =>
        '${String.fromCharCodes(runes.take(length))}$number$extension';
    while (length > 1 &&
        utf8.encode('${nameOf(length)}$_partSuffix').length > _maxNameBytes) {
      length--;
    }
    return nameOf(length);
  }
}
