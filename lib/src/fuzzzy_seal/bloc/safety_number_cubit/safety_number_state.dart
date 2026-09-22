part of 'safety_number_cubit.dart';

class SafetyNumberState {
  final StateStatus status;
  final String? safetyNumber;
  final bool isVerified;
  final DefaultFailure? failure;

  const SafetyNumberState({
    required this.status,
    this.safetyNumber,
    this.isVerified = false,
    this.failure,
  });

  SafetyNumberState copyWith({
    StateStatus? status,
    String? safetyNumber,
    bool? isVerified,
    DefaultFailure? failure,
  }) {
    return SafetyNumberState(
      status: status ?? this.status,
      safetyNumber: safetyNumber ?? this.safetyNumber,
      isVerified: isVerified ?? this.isVerified,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() =>
      'SafetyNumberState(status: $status, safetyNumber: $safetyNumber, isVerified: $isVerified, failure: $failure)';
}
