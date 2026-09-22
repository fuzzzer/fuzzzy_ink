import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'vault_groups_state.dart';

class VaultGroupsCubit extends Cubit<VaultGroupsState> {
  VaultGroupsCubit({
    required this.vaultRepository,
  }) : super(const VaultGroupsState());

  final VaultRepository vaultRepository;

  Future<void> loadGroups() async {
    emit(state.copyWith(status: StateStatus.loading));
    final res = await vaultRepository.getAllGroups();

    if (res is VaultSuccess) {
      emit(
        state.copyWith(
          status: StateStatus.success,
          groups: (res as VaultSuccess<List<VaultGroupData>>).data,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (res as VaultFailure).type,
        ),
      );
    }
  }

  Future<VaultResponse<VaultGroupData>> createGroup(
    VaultGroupData group,
  ) async {
    emit(state.copyWith(status: StateStatus.loading));
    final res = await vaultRepository.createGroup(group);

    if (res is VaultSuccess) {
      await loadGroups();
    } else {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (res as VaultFailure).type,
        ),
      );
    }
    return res;
  }

  Future<VaultResponse<VaultGroupData>> updateGroup(
    VaultGroupData group,
  ) async {
    emit(state.copyWith(status: StateStatus.loading));
    final res = await vaultRepository.updateGroup(group);

    if (res is VaultSuccess) {
      await loadGroups();
    } else {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (res as VaultFailure).type,
        ),
      );
    }
    return res;
  }

  Future<void> deleteGroup(String groupId) async {
    emit(state.copyWith(status: StateStatus.loading));
    final res = await vaultRepository.deleteGroup(groupId);

    if (res is VaultSuccess) {
      await loadGroups();
    } else {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (res as VaultFailure).type,
        ),
      );
    }
  }
}
