enum VaultFailureType {
  // Auth failures
  incorrectMasterPassword,
  incorrectCustomPassword,
  weakPassword,
  vaultNotInitialized,
  vaultAlreadyExists,

  /// Too many wrong master passwords in a row: the app lock's wait applies
  /// to the vault too, since the same password opens both.
  tooManyAttempts,

  /// The recovery key has a typo (wrong length or check character).
  recoveryKeyTypo,

  /// The recovery key does not open this vault (another device's key, or an
  /// old one replaced by a new key).
  recoveryKeyWrong,

  /// No recovery copy of this vault exists: no recovery key was kept when it
  /// got its own password.
  noRecoveryKey,

  /// The vault from the documents directory is not yet in its private
  /// folder; it neither opens nor is replaced until a start finishes the move.
  vaultMoveUnfinished,

  // CRUD failures
  itemNotFound,
  groupNotFound,
  duplicateItem,
  generalGroupUndeletable,

  // Storage failures
  storageReadError,
  storageWriteError,
  fileCorrupted,
  decryptionFailed,

  // Export/Import failures
  exportFailed,
  importFailed,
  invalidExportFile,
  exportPasswordIncorrect,

  // Directory failures
  directoryNotFound,
  directoryPermissionDenied,
  directoryReadError,

  // General
  unknown,
}
