part of 'basic_encryption_cubit.dart';

class BasicEncryptionState {
  final StateStatus status;
  final String? result;

  /// Whether [result] is sealed output (copyable) or opened plaintext (never
  /// copyable, copy_guard).
  final bool isResultSealed;
  final DefaultFailure? failure;

  const BasicEncryptionState({
    required this.status,
    this.result,
    this.isResultSealed = false,
    this.failure,
  });

  BasicEncryptionState copyWith({
    StateStatus? status,
    String? result,
    bool? isResultSealed,
    DefaultFailure? failure,
  }) {
    return BasicEncryptionState(
      status: status ?? this.status,
      result: result ?? this.result,
      isResultSealed: isResultSealed ?? this.isResultSealed,
      failure: failure,
    );
  }
}
