import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// The rules for file and folder names the app did not choose itself: a
/// received file's name is the sender's (`PROTOCOL.md` §7.3 only makes it a
/// bare name), so it is untrusted when it is shown, opened and stored
/// (`THREAT_MODEL.md` R14, R15).
abstract final class UserFileNames {
  /// The folder every desktop chat folder lives in, inside the user's
  /// Documents folder — the desktop twin of Android's `Downloads/Fuzzzy Ink`.
  static const appFolderName = 'Fuzzzy Ink';

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

  // -------------------------------------------------------------------------
  // Opening
  // -------------------------------------------------------------------------

  /// Programs, installers, scripts, shortcuts and anything else the desktop's
  /// default handler would run, install or follow instead of just showing.
  /// Windows: Outlook's blocked list plus the newer shell types; macOS and
  /// Linux: shell scripts, launchers, installers and disk images.
  static const desktopRiskyExtensions = <String>{
    // Windows programs and installers.
    'exe', 'com', 'scr', 'pif', 'cpl', 'msi', 'msp', 'mst', 'msu', 'msix',
    'msixbundle', 'appx', 'appxbundle', 'appinstaller', 'application',
    'appref-ms', 'xbap', 'gadget', 'xll', 'ocx', 'sys', 'drv', 'dll',
    // Windows scripts and script hosts.
    'bat', 'cmd', 'vb', 'vbs', 'vbe', 'vbp', 'js', 'jse', 'wsf', 'wsh', 'ws',
    'wsc', 'sct', 'hta', 'htc', 'ps1', 'ps1xml', 'ps2', 'ps2xml', 'psc1',
    'psc2', 'psd1', 'psm1', 'msh', 'msh1', 'msh2', 'mshxml', 'msh1xml',
    'msh2xml', 'bas', 'fxp', 'prg', 'mcf', 'shb', 'shs',
    // Windows shortcuts, shell and system settings.
    'lnk', 'url', 'website', 'scf', 'pcd', 'xnk', 'library-ms', 'search-ms',
    'searchconnector-ms', 'settingcontent-ms', 'reg', 'inf', 'ins', 'isp',
    'msc', 'its', 'osd', 'ops', 'prf', 'plg', 'grp', 'cnt', 'hpj', 'hlp',
    'chm', 'theme', 'themepack', 'desktopthemepackfile', 'udl', 'rdp', 'wsb',
    'diagcab', 'diagcfg', 'diagpkg', 'printerexport', 'webpnp', 'vsmacros',
    'vsw', 'asx', 'cer', 'crt', 'der',
    // Office databases and add-ins that run code when opened.
    'ade', 'adp', 'mad', 'maf', 'mag', 'mam', 'maq', 'mar', 'mas', 'mat',
    'mau', 'mav', 'maw', 'mda', 'mdb', 'mde', 'mdt', 'mdw', 'mdz',
    // Office documents with macros, Office add-ins and VSTO solutions.
    'docm', 'dotm', 'xlsm', 'xltm', 'xlam', 'xla', 'xlm', 'pptm', 'potm',
    'ppam', 'ppsm', 'sldm', 'wll', 'vsto',
    // Office files that fetch or run content: web queries, SYLK, OneNote,
    // web archives.
    'iqy', 'slk', 'one', 'onepkg', 'mht', 'mhtml',
    // Disk images that mount (and so skip the downloaded-file warning).
    'iso', 'img', 'vhd', 'vhdx', 'dmg',
    // Interpreters that are often associated.
    'jar', 'jnlp', 'py', 'pyc', 'pyo', 'pyw', 'pyz', 'pyzw', 'pl', 'rb',
    // macOS.
    'app', 'command', 'tool', 'terminal', 'pkg', 'mpkg', 'scpt', 'scptd',
    'applescript', 'workflow', 'action', 'prefpane', 'saver', 'osax', 'kext',
    'webloc', 'inetloc', 'fileloc', 'afploc',
    // Linux and shells everywhere.
    'sh', 'bash', 'zsh', 'csh', 'ksh', 'tcsh', 'desktop', 'run', 'appimage',
    'deb', 'rpm', 'snap', 'flatpak', 'flatpakref', 'flatpakrepo',
  };

  /// Android hands a package to the installer (the system one refuses an app
  /// that does not hold the install permission, but third-party installers
  /// and API 24–25 with "unknown sources" on accept it).
  static const androidRiskyExtensions = <String>{
    'apk',
    'apks',
    'apkm',
    'xapk',
  };

  /// Whether opening [fileName] with the default handler on [platform] could
  /// run, install or follow something. The check reads the extension the OS
  /// will see: invisible and direction characters removed, trailing dots and
  /// spaces dropped (Windows does), anything after a `:` dropped (an NTFS
  /// stream name), case ignored; a `{CLSID}` extension counts as risky.
  /// iOS opens nothing that runs.
  static bool isRiskyToOpen(String fileName, {TargetPlatform? platform}) {
    final risky = switch (platform ?? hostPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia =>
        desktopRiskyExtensions,
      TargetPlatform.android => androidRiskyExtensions,
      TargetPlatform.iOS => const <String>{},
    };
    if (risky.isEmpty) return false;

    for (final extension in realExtensions(fileName)) {
      if (risky.contains(extension)) return true;
      if (extension.startsWith('{') && extension.endsWith('}')) return true;
    }
    return false;
  }

  /// The lower-case extensions an OS may act on for [fileName] (see
  /// [isRiskyToOpen]); empty when the name has none.
  static List<String> realExtensions(String fileName) {
    final visible = fileName
        .replaceAll(_bidiControls, '')
        .replaceAll(_controls, '')
        .replaceAll(_invisibles, '');
    final colon = visible.indexOf(':');
    final candidates = {
      visible,
      if (colon != -1) visible.substring(0, colon),
    };

    final extensions = <String>[];
    for (final candidate in candidates) {
      final trimmed = candidate.replaceFirst(RegExp(r'[\s.]+$'), '');
      final dot = trimmed.lastIndexOf('.');
      if (dot == -1 || dot == trimmed.length - 1) continue;
      extensions.add(trimmed.substring(dot + 1).trim().toLowerCase());
    }
    return extensions;
  }

  // -------------------------------------------------------------------------
  // Storing
  // -------------------------------------------------------------------------

  /// The platform this process runs on, read the way the file code does
  /// (`dart:io`), not Flutter's overridable `defaultTargetPlatform`.
  static TargetPlatform get hostPlatform {
    if (Platform.isWindows) return TargetPlatform.windows;
    if (Platform.isMacOS) return TargetPlatform.macOS;
    if (Platform.isLinux) return TargetPlatform.linux;
    if (Platform.isIOS) return TargetPlatform.iOS;
    if (Platform.isAndroid) return TargetPlatform.android;
    return TargetPlatform.fuchsia;
  }

  static bool _isDesktop(TargetPlatform platform) =>
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux;

  /// Where a chat's files are written.
  ///
  /// * Windows, macOS, Linux — `<documents>/Fuzzzy Ink/<safe chat folder>`
  ///   ([safeChatFolderName]), so a chat can never write into one of the
  ///   user's own Documents folders, the vault's, or another chat's.
  /// * Android — `<documents>/<phone chat folder>` ([phoneChatFolderName]),
  ///   the app-private staging folder; the finished file moves to
  ///   `Downloads/Fuzzzy Ink/<phone chat folder>/`.
  /// * iOS — `<documents>/<phone chat folder>`, the app's own Documents
  ///   folder.
  static String chatFolderPath({
    required String documentsPath,
    required String chatName,
    required String chatId,
    TargetPlatform? platform,
  }) {
    if (!_isDesktop(platform ?? hostPlatform)) {
      return path.join(documentsPath, phoneChatFolderName(chatName));
    }
    return path.join(
      documentsPath,
      appFolderName,
      safeChatFolderName(chatName: chatName, chatId: chatId),
    );
  }

  static const _maxChatFolderNameLength = 60;
  static const _chatIdSuffixLength = 8;
  static const _fallbackChatFolderName = 'Chat';

  /// Device names Windows reserves, with or without an extension.
  static final _windowsReservedName = RegExp(
    r'^(con|prn|aux|nul|conin\$|conout\$|com[0-9¹²³]|lpt[0-9¹²³])$',
    caseSensitive: false,
  );

  /// [chatName] as one folder name every desktop accepts, followed by the
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

  /// [chatName] as one folder name on a phone (Android, iOS), without the
  /// chat id, so a chat keeps the folder it always had: only the cleaning
  /// that keeps the folder inside its parent is applied. Direction and
  /// control characters go, `/` and `\` become `_`, leading and trailing dots
  /// and spaces go (so `.` and `..` are gone too); `Chat` when nothing is
  /// left. Joiners stay, so an emoji sequence keeps its folder. Android's
  /// native side gets this name too (`UserFilesChannel`).
  static String phoneChatFolderName(String chatName) {
    final name = _trimDotsAndSpaces(
      chatName
          .replaceAll(_bidiControls, '')
          .replaceAll(_controls, '')
          .replaceAll(RegExp(r'[/\\]'), '_'),
    );
    return name.isEmpty ? _fallbackChatFolderName : name;
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
