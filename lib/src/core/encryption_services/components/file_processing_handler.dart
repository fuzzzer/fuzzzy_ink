import 'package:fuzzzy_seal/lib.dart';

class FileProcessingHandler {
  final Stream<FileProcessingProgress> progressStream;
  final void Function() pause;
  final void Function() resume;
  final void Function() cancel;

  FileProcessingHandler({
    required this.progressStream,
    required this.pause,
    required this.resume,
    required this.cancel,
  });
}
