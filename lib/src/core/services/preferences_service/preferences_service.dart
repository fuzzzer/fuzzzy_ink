// ignore_for_file: avoid_positional_boolean_parameters

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const _hasCompletedTutorialKey = 'has_completed_tutorial';

  bool get hasSeenOnboarding => _prefs.getBool(_hasSeenOnboardingKey) ?? false;
  Future<void> setHasSeenOnboarding(bool value) =>
      _prefs.setBool(_hasSeenOnboardingKey, value);

  bool get hasCompletedTutorial =>
      _prefs.getBool(_hasCompletedTutorialKey) ?? false;
  Future<void> setHasCompletedTutorial(bool value) =>
      _prefs.setBool(_hasCompletedTutorialKey, value);

  static const _lastSelectedTabKey = 'last_selected_tab';
  String get lastSelectedTab => _prefs.getString(_lastSelectedTabKey) ?? '/';
  Future<void> setLastSelectedTab(String path) =>
      _prefs.setString(_lastSelectedTabKey, path);

  static const _vaultLastSelectedTabIndexKey = 'vault_last_selected_tab_index';
  int get vaultLastSelectedTabIndex =>
      _prefs.getInt(_vaultLastSelectedTabIndexKey) ?? 0;
  Future<void> setVaultLastSelectedTabIndex(int index) =>
      _prefs.setInt(_vaultLastSelectedTabIndexKey, index);
}
