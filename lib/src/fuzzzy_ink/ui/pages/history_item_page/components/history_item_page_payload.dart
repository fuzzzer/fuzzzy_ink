import 'package:fuzzzy_ink/src/src.dart';

/// One row of a person's history, opened from their page.
class HistoryItemPagePayload {
  const HistoryItemPagePayload({
    required this.chat,
    required this.message,
    this.fileSize,
  });

  final ChatGeneralData chat;
  final MessageData message;

  /// Formatted ("3.1 MB") when the person page already knew it.
  final String? fileSize;
}
