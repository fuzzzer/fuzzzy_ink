part of 'safety_number_cubit.dart';

class SafetyNumberState {
  final StateStatus status;

  /// The digits and the version of the computation that produced them; the
  /// page shows both.
  final SafetyNumber? safetyNumber;
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
    SafetyNumber? safetyNumber,
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
      'SafetyNumberState(status: $status, safetyNumber: ${safetyNumber?.version}/${safetyNumber?.digits}, isVerified: $isVerified, failure: $failure)';
}
