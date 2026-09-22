part of 'invitation_acceptance_cubit.dart';

class InvitationAcceptanceState {
  final StateStatus status;
  final ChatGeneralData? chatData;
  final CryptoCoreAcceptance? generatedAcceptance;
  final ChatCreationFailure? failure;

  const InvitationAcceptanceState({
    required this.status,
    this.chatData,
    this.generatedAcceptance,
    this.failure,
  });

  InvitationAcceptanceState copyWith({
    StateStatus? status,
    ChatGeneralData? chatData,
    CryptoCoreAcceptance? generatedAcceptance,
    ChatCreationFailure? failure,
  }) {
    return InvitationAcceptanceState(
      status: status ?? this.status,
      chatData: chatData ?? this.chatData,
      generatedAcceptance: generatedAcceptance ?? this.generatedAcceptance,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() {
    return 'InvitationAcceptanceState(status: $status, chatData: $chatData, generatedAcceptance: $generatedAcceptance, failure: $failure)';
  }
}
