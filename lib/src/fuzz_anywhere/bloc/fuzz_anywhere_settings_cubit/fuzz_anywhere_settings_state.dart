part of 'fuzz_anywhere_settings_cubit.dart';

class FuzzAnywhereSettingsState {
  const FuzzAnywhereSettingsState({
    this.settings = FuzzAnywhereSettings.standard,
    this.isLoaded = false,
    this.copiesAutomatically = false,
  });

  final FuzzAnywhereSettings settings;

  /// Read from the sealed store at least once this run. Before that the
  /// settings are the standard ones (off), as far as anyone outside knows.
  final bool isLoaded;

  /// The Android sheet's "Copy automatically next time" (not sealed: the
  /// sheet keeps it; off where there is no sheet).
  final bool copiesAutomatically;

  /// On, and known to be on.
  bool get isOn => isLoaded && settings.isOn;

  FuzzAnywhereSettingsState copyWith({
    FuzzAnywhereSettings? settings,
    bool? isLoaded,
    bool? copiesAutomatically,
  }) {
    return FuzzAnywhereSettingsState(
      settings: settings ?? this.settings,
      isLoaded: isLoaded ?? this.isLoaded,
      copiesAutomatically: copiesAutomatically ?? this.copiesAutomatically,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FuzzAnywhereSettingsState &&
      other.settings == settings &&
      other.isLoaded == isLoaded &&
      other.copiesAutomatically == copiesAutomatically;

  @override
  int get hashCode => Object.hash(settings, isLoaded, copiesAutomatically);

  @override
  String toString() => 'FuzzAnywhereSettingsState($settings, '
      'loaded: $isLoaded, copies automatically: $copiesAutomatically)';
}
