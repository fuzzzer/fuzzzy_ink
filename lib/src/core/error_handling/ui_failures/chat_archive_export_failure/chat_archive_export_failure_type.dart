import 'package:fuzzzy_seal/lib.dart';

/// Why a chat archive export produced no file. History is readable only
/// while the store is open, so a locked store fails before anything is
/// written; an empty chat has nothing to seal.
enum ChatArchiveExportFailureType {
  storeLocked,
  nothingToExport,
  unknown;

  String toUiMessage(
    FuzzzySealLocalizations localizations, {
    String? customUnknownMessage,
  }) {
    return switch (this) {
      ChatArchiveExportFailureType.storeLocked =>
        localizations.exportChatArchiveStoreLocked,
      ChatArchiveExportFailureType.nothingToExport =>
        localizations.exportChatArchiveNothingToExport,
      ChatArchiveExportFailureType.unknown =>
        customUnknownMessage ?? localizations.exportChatArchiveFailed,
    };
  }
}
