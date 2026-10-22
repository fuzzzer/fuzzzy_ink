import 'package:isar_community/isar.dart';

part 'stored_chat_preferences.g.dart';

@Collection()
class StoredChatPreferences {
  Id id = Isar.autoIncrement;

  String? theme;

  bool showTimestamps = true;

  DateTime lastUpdated = DateTime.now();
}
