/// A message as it is shown on screen, where no character may hide or
/// reorder words: bidirectional controls and invisible characters are shown
/// as their codes ("[U+202E]"), the same way the "Lock from other apps"
/// sheet shows text another app selected (`SelectedText.visible` in the
/// Android sheet), so the person who opens it sees what the sender saw
/// (owner, 2026-10-30). Only the display changes; the message is kept as
/// it came.
abstract final class VisibleText {
  /// Controls, direction marks and overrides, and characters that take no
  /// space or look like a space. Joiners and variation selectors stay: emoji
  /// and some scripts need them, and they hide no words. Line breaks and
  /// tabs stay too.
  static final _hiding = RegExp(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u00AD\u061C'
    r'\u115F\u1160\u180E\u200B\u200E\u200F\u202A-\u202E\u2060-\u2064'
    r'\u2066-\u2069\u3164\uFEFF\uFFA0\uFFF9-\uFFFB]',
  );

  static String of(String text) =>
      text.replaceAllMapped(_hiding, (match) => '[U+${_code(match[0]!)}]');

  static String _code(String character) =>
      character.codeUnitAt(0).toRadixString(16).toUpperCase().padLeft(4, '0');
}
