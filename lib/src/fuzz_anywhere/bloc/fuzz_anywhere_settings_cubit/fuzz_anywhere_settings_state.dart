part of 'fuzz_anywhere_settings_cubit.dart';

class FuzzAnywhereSettingsState {
  const FuzzAnywhereSettingsState({
    this.settings = FuzzAnywhereSettings.standard,
    this.isLoaded = false,
  });

  final FuzzAnywhereSettings settings;

  /// Read from the sealed store at least once this run. Before that the
  /// settings are the standard ones (off), as far as anyone outside knows.
  final bool isLoaded;

  /// On, and known to be on.
  bool get isOn => isLoaded && settings.isOn;

  @override
  bool operator ==(Object other) =>
      other is FuzzAnywhereSettingsState &&
      other.settings == settings &&
      other.isLoaded == isLoaded;

  @override
  int get hashCode => Object.hash(settings, isLoaded);

  @override
  String toString() =>
      'FuzzAnywhereSettingsState($settings, loaded: $isLoaded)';
}
