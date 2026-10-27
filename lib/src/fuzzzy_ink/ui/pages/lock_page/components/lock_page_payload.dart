import 'package:fuzzzy_ink/src/src.dart';

/// What `AppRouter.lockFor` takes as `extra` (a bare [ChatGeneralData] or
/// chat id works too, as does `?chat=<id>`).
///
/// [returnsToPerson]: the flow was opened from that person's page, so Done
/// closes it and the page underneath shows the new row; from Home, Done goes
/// to the person's page.
class LockPagePayload {
  const LockPagePayload({
    this.chat,
    this.chatId,
    this.returnsToPerson = false,
  });

  /// Lock with a password: no person.
  const LockPagePayload.password()
      : chat = null,
        chatId = null,
        returnsToPerson = false;

  final ChatGeneralData? chat;

  /// When only the id is at hand; the page reads the person first.
  final String? chatId;
  final bool returnsToPerson;

  bool get isPassword => chat == null && chatId == null;

  /// Reads a route's `extra` and `?chat=` into a payload.
  factory LockPagePayload.fromRoute(Object? extra, String? chatQuery) {
    return switch (extra) {
      final LockPagePayload payload => payload,
      final ChatGeneralData chat => LockPagePayload(chat: chat),
      final String chatId => LockPagePayload(chatId: chatId),
      _ => LockPagePayload(chatId: chatQuery),
    };
  }
}
