/// Which history row is new, handed from Lock and Open to the person's page
/// (DESIGN.md section 10, "Opened → where it went": the new row glows once).
///
/// Lock and Open [mark] the row they wrote just before they land on the
/// person; the person page asks [take] once when it builds its list and
/// tints that row (`RowTint`). One row per person; a second mark replaces
/// the first, and [take] clears it, so the glow plays once.
abstract final class RecentHistoryRow {
  static final Map<String, int> _newRows = {};

  static void mark({required String chatId, required int messageId}) {
    _newRows[chatId] = messageId;
  }

  /// The new row of [chatId]'s history, once; null when there is none.
  static int? take(String chatId) => _newRows.remove(chatId);

  /// Without clearing it (for a page that rebuilds before it shows rows).
  static int? peek(String chatId) => _newRows[chatId];

  /// Every mark goes: the app starts over (first run, or after "Erase
  /// everything").
  static void forgetAll() => _newRows.clear();
}
