part of 'chat_general_data_list_cubit.dart';

class ChatGeneralDataListState {
  final StateStatus status;
  final List<ChatGeneralData>? chatList;
  final DefaultFailure? failure;

  final StateStatus actionStatus;
  final ActionType actionType;
  final DefaultFailure? actionFailure;

  const ChatGeneralDataListState({
    required this.status,
    this.chatList,
    this.failure,
    this.actionStatus = StateStatus.initial,
    this.actionType = ActionType.none,
    this.actionFailure,
  });

  ChatGeneralDataListState copyWith({
    StateStatus? status,
    List<ChatGeneralData>? chatList,
    DefaultFailure? failure,
    StateStatus? actionStatus,
    ActionType? actionType,
    DefaultFailure? actionFailure,
  }) {
    return ChatGeneralDataListState(
      status: status ?? this.status,
      chatList: chatList ?? this.chatList,
      failure: failure ?? this.failure,
      actionStatus: actionStatus ?? this.actionStatus,
      actionType: actionType ?? this.actionType,
      actionFailure: actionFailure ?? this.actionFailure,
    );
  }

  @override
  String toString() {
    return 'ChatGeneralDataListState(status: $status, chatList: $chatList, failure: $failure, actionStatus: $actionStatus, actionType: $actionType, actionFailure: $actionFailure)';
  }
}
