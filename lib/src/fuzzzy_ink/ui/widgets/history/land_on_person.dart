import 'package:flutter/widgets.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:go_router/go_router.dart';

/// Where Lock and Open go when they are done: the person's page, with the
/// row they just wrote glowing once ([RecentHistoryRow]).
///
/// Opened from that person's page ([returnsToPerson]), the flow just closes
/// and the page underneath shows the row. Opened from Home, Home comes back
/// and the person opens on top of it ([HomePage.openPerson]). [toast] (with
/// [castMoment], when Fuzzzy Cast is on) then says where it went.
void landOnPerson(
  BuildContext context, {
  required ChatGeneralData chat,
  required bool returnsToPerson,
  int? historyRowId,
  String? toast,
  FuzzzyCastMoment? castMoment,
}) {
  if (historyRowId != null) {
    RecentHistoryRow.mark(chatId: chat.chatId, messageId: historyRowId);
  }

  void say() {
    final overlayContext = navigatorKey.currentState?.overlay?.context;
    if (toast == null || overlayContext == null || !overlayContext.mounted) {
      return;
    }
    showInkToast(overlayContext, message: toast, castMoment: castMoment);
  }

  final router = GoRouter.of(context);
  if (returnsToPerson && router.canPop()) {
    router.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => say());
    return;
  }
  // Home first, then the person on top of it, in one go (as a tapped link
  // does): this flow's context is still mounted until the next frame.
  router.go(AppRouter.home);
  HomePage.openPerson(context, chat);
  WidgetsBinding.instance.addPostFrameCallback((_) => say());
}
