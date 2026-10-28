/// Settings → Other apps. Sealed under the store key like the auto-lock
/// times, so editing a file cannot turn the feature on.
class FuzzAnywhereSettings {
  const FuzzAnywhereSettings({
    required this.isOn,
    required this.locksAgainAfterUse,
  });

  /// "Lock from other apps" off; "Lock again after each use" on.
  static const standard = FuzzAnywhereSettings(
    isOn: false,
    locksAgainAfterUse: true,
  );

  final bool isOn;

  /// The app locks again when an outside use that unlocked it is done.
  final bool locksAgainAfterUse;

  /// `null` when the map is not these two switches.
  static FuzzAnywhereSettings? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final isOn = json['on'];
    final locksAgain = json['lockAgain'];
    if (isOn is! bool || locksAgain is! bool) return null;
    return FuzzAnywhereSettings(isOn: isOn, locksAgainAfterUse: locksAgain);
  }

  Map<String, bool> toJson() => {'on': isOn, 'lockAgain': locksAgainAfterUse};

  FuzzAnywhereSettings copyWith({bool? isOn, bool? locksAgainAfterUse}) {
    return FuzzAnywhereSettings(
      isOn: isOn ?? this.isOn,
      locksAgainAfterUse: locksAgainAfterUse ?? this.locksAgainAfterUse,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FuzzAnywhereSettings &&
      other.isOn == isOn &&
      other.locksAgainAfterUse == locksAgainAfterUse;

  @override
  int get hashCode => Object.hash(isOn, locksAgainAfterUse);

  @override
  String toString() =>
      'FuzzAnywhereSettings(on: $isOn, lockAgain: $locksAgainAfterUse)';
}
