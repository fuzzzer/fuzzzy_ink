part of 'basics_fuzzed_files_cubit.dart';

class BasicsFuzzedFilesState {
  final StateStatus status;
  final List<String> filePaths;

  const BasicsFuzzedFilesState({
    this.status = StateStatus.initial,
    this.filePaths = const [],
  });

  @override
  String toString() =>
      'BasicsFuzzedFilesState(status: $status, files: ${filePaths.length})';
}
