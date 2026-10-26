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

  /// Fuzzzy Cast, the optional character layer: off until the person turns
  /// it on (first run or Settings).
  static const _fuzzzyCastEnabledKey = 'fuzzzy_cast_enabled';
  bool get fuzzzyCastEnabled => _prefs.getBool(_fuzzzyCastEnabledKey) ?? false;
  Future<void> setFuzzzyCastEnabled(bool value) =>
      _prefs.setBool(_fuzzzyCastEnabledKey, value);

  /// Fuzzzy Cast's soft sounds, off by default; shown only while Fuzzzy Cast
  /// is on.
  static const _fuzzzyCastSoftSoundsKey = 'fuzzzy_cast_soft_sounds';
  bool get fuzzzyCastSoftSounds =>
      _prefs.getBool(_fuzzzyCastSoftSoundsKey) ?? false;
  Future<void> setFuzzzyCastSoftSounds(bool value) =>
      _prefs.setBool(_fuzzzyCastSoftSoundsKey, value);

  static const _vaultLastSelectedTabIndexKey = 'vault_last_selected_tab_index';
  int get vaultLastSelectedTabIndex =>
      _prefs.getInt(_vaultLastSelectedTabIndexKey) ?? 0;
  Future<void> setVaultLastSelectedTabIndex(int index) =>
      _prefs.setInt(_vaultLastSelectedTabIndexKey, index);

  /// Settings → My safe → Copy passwords: on by default (DESIGN.md section
  /// 14). Off hides every My safe copy button; the copy guard's own rule
  /// (`allowVaultPasswordCopy`) still comes first.
  static const _vaultPasswordCopyKey = 'vault_password_copy';
  bool get vaultPasswordCopy => _prefs.getBool(_vaultPasswordCopyKey) ?? true;
  Future<void> setVaultPasswordCopy(bool value) =>
      _prefs.setBool(_vaultPasswordCopyKey, value);
}
