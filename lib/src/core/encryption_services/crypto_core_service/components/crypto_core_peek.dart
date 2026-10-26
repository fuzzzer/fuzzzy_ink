/// What a pasted text or a chosen file is (`CryptoCoreService.peekPasted`,
/// `CryptoCoreService.peekFile`), recognised before anything is spent.
enum CryptoCorePeekKind {
  /// A signed invitation; [CryptoCorePeek.chatId] is its clear chat id.
  invitation,

  /// A signed acceptance (a reply); [CryptoCorePeek.chatId] is its chat id.
  acceptance,

  /// A chat message; [CryptoCorePeek.chatId] is the person's chat that sent
  /// it, or null when it is from none of them.
  message,

  /// A chat file; [CryptoCorePeek.chatId] as for a message.
  chatFile,

  /// Text locked with a password.
  passwordText,

  /// A file locked with a password (Basics, or a saved history).
  passwordFile,

  /// Made by a newer Fuzzzy Ink.
  newerVersion,

  /// Not Fuzzzy Ink's at all.
  notFuzzzy,

  /// Fuzzzy Ink's, but cut off or broken.
  damaged,
}

/// The answer of a peek. [chatId] is only ever a routing hint: the real
/// open checks everything again.
class CryptoCorePeek {
  const CryptoCorePeek({
    required this.kind,
    this.chatId,
    this.isTextFile = false,
  });

  final CryptoCorePeekKind kind;
  final String? chatId;

  /// A file that holds locked text (a `.fuzz` file made by "Send as a
  /// file"): it opens like a paste of its text.
  final bool isTextFile;

  @override
  bool operator ==(Object other) =>
      other is CryptoCorePeek &&
      other.kind == kind &&
      other.chatId == chatId &&
      other.isTextFile == isTextFile;

  @override
  int get hashCode => Object.hash(kind, chatId, isTextFile);

  @override
  String toString() =>
      'CryptoCorePeek($kind, chatId: $chatId, isTextFile: $isTextFile)';
}
