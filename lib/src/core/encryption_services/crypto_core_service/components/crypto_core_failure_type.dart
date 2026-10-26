/// One case per `CoreError` variant of the Rust crypto core — the only form
/// in which a core failure reaches a cubit.
enum CryptoCoreFailureType {
  unsupportedFormat,

  /// Made by a newer Fuzzzy Ink: a version or a type byte this build does
  /// not know ("Needs a newer Fuzzzy Ink").
  newerVersion,
  invalidSignature,
  invitationAlreadyUsed,
  wrongChat,
  replay,
  tooOld,
  corrupt,
  wrongPassword,
  storeLocked,
  unknownChat,
  io,
  cancelled,
  internal,
}
