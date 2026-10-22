enum VaultFailureType {
  // Auth failures
  incorrectMasterPassword,
  incorrectCustomPassword,
  weakPassword,
  vaultNotInitialized,
  vaultAlreadyExists,

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
