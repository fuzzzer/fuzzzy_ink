enum AuthStateStatus {
  /// Boot: the secure storage is still being read. No access, like [locked].
  initial,

  /// No master password yet: the first run sets one. No access.
  setupRequired,

  locked,

  unlocking,

  authenticated,

  /// The secure storage could not be read. The app fails closed: no access
  /// until a retry reads it.
  storageUnavailable;

  bool get isInitial => this == initial;
  bool get isSetupRequired => this == setupRequired;
  bool get isLocked => this == locked;
  bool get isUnlocking => this == unlocking;
  bool get isAuthenticated => this == authenticated;
  bool get isStorageUnavailable => this == storageUnavailable;

  /// Only an unlocked store gives access; there is no "lock off" state.
  bool get hasAccess => this == authenticated;
}
