import 'dart:typed_data';

import 'package:fuzzzy_ink/lib.dart';

/// A chat-mode file receive that has started: the output path (the sender's
/// original file name inside the directory the caller chose — known only once
/// the container's key message is open), the handler streaming it there, and
/// the file key sealed under the chat's history key, with which the kept
/// container opens again (`CryptoCoreService.openKeptFileForChat`).
class CryptoCoreReceivedFile {
  final String outputPath;
  final FileProcessingHandler handler;
  final Uint8List keptKey;

  const CryptoCoreReceivedFile({
    required this.outputPath,
    required this.handler,
    required this.keptKey,
  });
}
