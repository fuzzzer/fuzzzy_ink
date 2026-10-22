import 'package:isar_community/isar.dart';

part 'stored_user_auth_preferences.g.dart';

// TODO: Run 'flutter pub run build_runner build' to generate the .g.dart file

@Collection()
class StoredUserAuthPreferences {
  // Use a fixed ID for a singleton object pattern. This ensures you only
  // ever have one of this object in the database.
  final Id id = 1;

  late bool isAuthenticationOnceEnabled;

  late DateTime lastUpdated;
}
