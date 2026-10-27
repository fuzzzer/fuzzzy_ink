part of 'fuzzzy_cast_settings_cubit.dart';

class FuzzzyCastSettingsState {
  const FuzzzyCastSettingsState({
    required this.isEnabled,
    required this.softSounds,
  });

  final bool isEnabled;

  /// Only meaningful while [isEnabled].
  final bool softSounds;

  FuzzzyCastSettingsState copyWith({bool? isEnabled, bool? softSounds}) {
    return FuzzzyCastSettingsState(
      isEnabled: isEnabled ?? this.isEnabled,
      softSounds: softSounds ?? this.softSounds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FuzzzyCastSettingsState &&
      other.isEnabled == isEnabled &&
      other.softSounds == softSounds;

  @override
  int get hashCode => Object.hash(isEnabled, softSounds);

  @override
  String toString() =>
      'FuzzzyCastSettingsState(isEnabled: $isEnabled, softSounds: $softSounds)';
}
