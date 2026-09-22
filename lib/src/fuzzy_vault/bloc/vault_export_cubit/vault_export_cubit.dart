import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'vault_export_state.dart';

class VaultExportCubit extends Cubit<VaultExportState> {
  VaultExportCubit({
    required this.exportRepository,
  }) : super(const VaultExportState());

  final VaultExportRepository exportRepository;

  Future<void> exportVault(
    List<VaultItemMetadata> items,
    List<VaultGroupData> groups,
    String directory,
    String password,
  ) async {
    emit(state.copyWith(status: StateStatus.loading));
    final res =
        await exportRepository.exportVault(items, groups, directory, password);

    if (res is VaultSuccess) {
      emit(state.copyWith(status: StateStatus.success));
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
