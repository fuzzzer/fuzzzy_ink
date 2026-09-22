import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'vault_search_state.dart';

class VaultSearchCubit extends Cubit<VaultSearchState> {
  VaultSearchCubit({
    required this.vaultRepository,
  }) : super(const VaultSearchState());

  final VaultRepository vaultRepository;
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 300);

  void updateQuery(String query) {
    emit(state.copyWith(query: query));
    if (query.trim().isEmpty) {
      emit(state.copyWith(status: StateStatus.success, results: []));
      return;
    }

    _searchDebouncer.run(() async {
      emit(state.copyWith(status: StateStatus.loading));
      final res = await vaultRepository.searchItems(query.trim());

      if (res is VaultSuccess) {
        emit(
          state.copyWith(
            status: StateStatus.success,
            results: (res as VaultSuccess<List<VaultItemMetadata>>).data,
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
    });
  }

  void clearSearch() {
    emit(state.copyWith(query: '', results: [], status: StateStatus.initial));
  }

  @override
  Future<void> close() {
    _searchDebouncer.close();
    return super.close();
  }
}
