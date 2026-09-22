import 'file_processing_failure_type.dart';

export 'components.dart';
export 'file_processing_failure_type.dart';

class FileProcessingFailure {
  ///Not to be used to show user
  final String? internalMessage;

  ///To be used to generate message for user, for ui to generate localized message
  final FileProcessingFailureType type;

  FileProcessingFailure({
    this.internalMessage,
    required this.type,
  });
}
