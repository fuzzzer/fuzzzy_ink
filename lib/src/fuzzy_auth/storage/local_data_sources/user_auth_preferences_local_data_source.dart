import 'package:isar_community/isar.dart';

import '../../data/models/user_auth_preferences.dart';
import '../storage_models/stored_user_auth_preferences.dart';

class UserAuthPreferencesLocalDataSource {
  final Isar isar;

  UserAuthPreferencesLocalDataSource({required this.isar});

  Future<StoredUserAuthPreferences?> get() async {
    return isar.storedUserAuthPreferences.get(1);
  }

  Future<void> update(UserAuthPreferences model) async {
    final storedModel = StoredUserAuthPreferences()
      ..isAuthenticationOnceEnabled = model.isAuthenticationOnceEnabled
      ..lastUpdated = DateTime.now();

    await isar.writeTxn(() async {
      await isar.storedUserAuthPreferences.put(storedModel);
    });
  }

  Future<bool> delete() async {
    return isar.writeTxn(() async {
      return isar.storedUserAuthPreferences.delete(1);
    });
  }
}
