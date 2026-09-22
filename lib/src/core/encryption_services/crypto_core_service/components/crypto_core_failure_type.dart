/// One case per `CoreError` variant of the Rust crypto core — the only form
/// in which a core failure reaches a cubit.
enum CryptoCoreFailureType {
  unsupportedFormat,
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
