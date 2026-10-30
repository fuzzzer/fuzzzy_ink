import 'package:flutter/foundation.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// One row of a person's history, opened from their page.
class HistoryItemPagePayload {
  const HistoryItemPagePayload({
    required this.chat,
    required this.message,
    this.fileSize,
    this.onGone,
  });

  final ChatGeneralData chat;
  final MessageData message;

  /// Formatted ("3.1 MB") when the person page already knew it.
  final String? fileSize;

  /// Called once the screen has left, however it left: closed, or taken
  /// away when another place replaced the app's pages (which completes no
  /// push). "Lock from other apps" waits for it to lock again.
  final VoidCallback? onGone;
}
