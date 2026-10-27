import 'package:fuzzzy_ink/lib.dart';

enum ChatCreationFailureType {
  existingName,
  ownInvitation,
  invalidInvitation,
  invalidAcceptance,
  invitationAlreadyUsed,
  wrongChat,

  /// Made by a newer Fuzzzy Ink.
  newerApp,
  unknown;

  String toUiMessage(
    FuzzzyInkLocalizations localizations, {
    String? customUnknownMessage,
  }) {
    return switch (this) {
      ChatCreationFailureType.existingName =>
        localizations.chatWithIndicatedNameAlreadyExists,
      ChatCreationFailureType.ownInvitation =>
        localizations.cantAcceptOwnInvitation,
      ChatCreationFailureType.invalidInvitation =>
        localizations.invalidInvitation,
      ChatCreationFailureType.invalidAcceptance =>
        localizations.invalidAcceptance,
      ChatCreationFailureType.invitationAlreadyUsed =>
        localizations.invitationAlreadyUsed,
      ChatCreationFailureType.wrongChat => localizations.wrongChatBlob,
      ChatCreationFailureType.newerApp => localizations.openErrorNewerTitle,
      ChatCreationFailureType.unknown =>
        customUnknownMessage ?? localizations.failedToCreateChat,
    };
  }
}
