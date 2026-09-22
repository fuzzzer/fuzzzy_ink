import 'package:fuzzzy_seal/src/fuzzzy_seal/storage/storage.dart';

class ChatPreferences {
  final String? theme;
  final bool showTimestamps;
  final DateTime lastUpdated;

  ChatPreferences({
    required this.showTimestamps,
    required this.lastUpdated,
    this.theme,
  });

  factory ChatPreferences.fromStored(StoredChatPreferences stored) {
    return ChatPreferences(
      theme: stored.theme,
      showTimestamps: stored.showTimestamps,
      lastUpdated: stored.lastUpdated,
    );
  }

  StoredChatPreferences toStored() {
    return StoredChatPreferences()
      ..theme = theme
      ..showTimestamps = showTimestamps
      ..lastUpdated = lastUpdated;
  }

  ChatPreferences copyWith({
    String? theme,
    bool? showTimestamps,
    DateTime? lastUpdated,
  }) {
    return ChatPreferences(
      theme: theme ?? this.theme,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() =>
      'ChatPreferences(theme: $theme, showTimestamps: $showTimestamps, lastUpdated: $lastUpdated)';
}
