import 'package:fuzzzy_ink/lib.dart';

/// Why a file job ended in [FileProcessingStatus.failed]. The chat-receive
/// prepare step consumes the container's key message, so a failure *after*
/// it ([cannotOpenAskResend]) — or a cancel after it ([cancelled], the row
/// stays [FileProcessingStatus.canceled]) — is terminal for that container:
/// the sender has to send it again; the other cases leave nothing consumed.
enum FileProcessingFailureType {
  wrongPassword,
  alreadyUnfuzzed,
  wrongChat,
  tooOld,
  corrupt,
  stillArriving,
  cannotOpenAskResend,
  cancelled,
  unknown;

  String toUiMessage(
    FuzzzyInkLocalizations localizations, {
    String? customUnknownMessage,
  }) {
    return switch (this) {
      FileProcessingFailureType.wrongPassword =>
        localizations.wrongPasswordFile,
      FileProcessingFailureType.alreadyUnfuzzed =>
        localizations.alreadyReceived,
      FileProcessingFailureType.wrongChat => localizations.wrongChatBlob,
      FileProcessingFailureType.tooOld => localizations.fileTooOld,
      FileProcessingFailureType.corrupt => localizations.fileCorrupt,
      FileProcessingFailureType.stillArriving =>
        localizations.fileStillArriving,
      FileProcessingFailureType.cannotOpenAskResend =>
        localizations.fileCannotBeOpenedAskToResend,
      FileProcessingFailureType.cancelled => localizations.fileCancelled,
      FileProcessingFailureType.unknown =>
        customUnknownMessage ?? localizations.unknownError,
    };
  }
}
