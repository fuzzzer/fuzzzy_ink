enum AuthStateStatus {
  /// Boot: the store is still opening. No access yet, like [locked].
  initial,

  noAuthRequired,

  locked,

  unlocking,

  authenticated;

  bool get isInitial => this == initial;
  bool get isNoAuthRequired => this == noAuthRequired;
  bool get isLocked => this == locked;
  bool get isUnlocking => this == unlocking;
  bool get isAuthenticated => this == authenticated;
  bool get hasAccess => this == authenticated || this == noAuthRequired;
}
