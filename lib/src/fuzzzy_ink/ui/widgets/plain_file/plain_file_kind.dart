import 'package:path/path.dart' as path;

/// What the in-app viewer can show of a plain file, by its extension: the
/// image formats Flutter decodes itself, and plain text. Everything else
/// (PDF included — no viewer dependency is shipped) is "Save" only; the app
/// never hands a plain file to another app to open.
enum PlainFileKind {
  image,
  text,
  none;

  static const _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
  };

  static const _textExtensions = {
    '.txt',
    '.md',
    '.csv',
    '.json',
    '.log',
    '.xml',
    '.yaml',
    '.yml',
  };

  /// The largest text file the viewer reads into memory.
  static const maxTextBytes = 1024 * 1024;

  static PlainFileKind of(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    if (_imageExtensions.contains(extension)) return image;
    if (_textExtensions.contains(extension)) return text;
    return none;
  }
}
