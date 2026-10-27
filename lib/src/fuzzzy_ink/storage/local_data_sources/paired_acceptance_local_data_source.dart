import 'package:shared_preferences/shared_preferences.dart';

/// The acceptance that completed each chat this device invited to, kept so a
/// second, different acceptance for the same chat can be told apart from the
/// same one arriving twice. An acceptance is public pairing data (it travels
/// over any channel), so it is kept as text, not sealed.
class PairedAcceptanceLocalDataSource {
  PairedAcceptanceLocalDataSource({required SharedPreferences prefs})
      : _prefs = prefs;

  static const _keyPrefix = 'paired_acceptance_';

  final SharedPreferences _prefs;

  String? read(String chatId) => _prefs.getString('$_keyPrefix$chatId');

  Future<void> write(String chatId, String acceptance) =>
      _prefs.setString('$_keyPrefix$chatId', acceptance);

  Future<void> delete(String chatId) => _prefs.remove('$_keyPrefix$chatId');
}
