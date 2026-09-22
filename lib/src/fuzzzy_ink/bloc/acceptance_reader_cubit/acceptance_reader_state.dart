part of 'acceptance_reader_cubit.dart';

class AcceptanceReaderState {
  final StateStatus status;
  final CryptoCoreAcceptance? acceptance;
  final DefaultFailure? failure;

  const AcceptanceReaderState({
    required this.status,
    this.acceptance,
    this.failure,
  });

  AcceptanceReaderState copyWith({
    StateStatus? status,
    CryptoCoreAcceptance? acceptance,
    DefaultFailure? failure,
  }) {
    return AcceptanceReaderState(
      status: status ?? this.status,
      acceptance: acceptance ?? this.acceptance,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() =>
      'AcceptanceReaderState(status: $status, acceptance: $acceptance, failure: $failure)';
}
