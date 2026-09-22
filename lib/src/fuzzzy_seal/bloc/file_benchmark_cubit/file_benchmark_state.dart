part of 'file_benchmark_cubit.dart';

class FileBenchmarkState {
  final StateStatus status;
  final FileBenchmarkResult? result;
  final DefaultFailure? failure;

  const FileBenchmarkState({
    required this.status,
    this.result,
    this.failure,
  });

  FileBenchmarkState copyWith({
    StateStatus? status,
    FileBenchmarkResult? result,
    DefaultFailure? failure,
  }) {
    return FileBenchmarkState(
      status: status ?? this.status,
      result: result ?? this.result,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() =>
      'FileBenchmarkState(status: $status, result: $result, failure: $failure)';
}
