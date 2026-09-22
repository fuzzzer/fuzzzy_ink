import 'package:fuzzzy_seal/lib.dart';

/// A chat-mode file receive that has started: the output path (the sender's
/// original file name inside the directory the caller chose — known only once
/// the container's key message is open) and the handler streaming it there.
class CryptoCoreReceivedFile {
  final String outputPath;
  final FileProcessingHandler handler;

  const CryptoCoreReceivedFile({
    required this.outputPath,
    required this.handler,
  });
}
