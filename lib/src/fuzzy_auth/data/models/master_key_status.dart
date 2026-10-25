/// Where the master password stands on this device.
enum MasterKeyStatus {
  /// No master password yet: the first run must set one.
  notSetUp,

  /// A master password exists; the app opens with it.
  ready,
}
