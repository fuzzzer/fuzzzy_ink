import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'vault_items_state.dart';

class VaultItemsCubit extends Cubit<VaultItemsState> {
  VaultItemsCubit({
    required this.vaultRepository,
  }) : super(const VaultItemsState()) {
    _updatesSubscription = vaultRepository.vaultDataUpdates.listen((_) {
      loadItems();
    });
  }

  final VaultRepository vaultRepository;
  late final StreamSubscription<VaultDataUpdated> _updatesSubscription;
  final Debouncer _autoSaveDebouncer = Debouncer(milliseconds: 2000);

  /// The open safe's key, for the rows' labels ([loadItems]); a closed key
  /// opens nothing and the rows show their types.
  VaultKey? _key;

  /// Loads the list, then the rows' labels with [key] (kept for the
  /// reloads after a change).
  Future<void> loadItems({VaultKey? key}) async {
    if (key != null) _key = key;
    emit(state.copyWith(status: StateStatus.loading));
    final res = await vaultRepository.getAllItems();
    if (res is VaultFailure) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (res as VaultFailure).type,
        ),
      );
      return;
    }

    final items = (res as VaultSuccess<List<VaultItemMetadata>>).data;
    emit(
      state.copyWith(
        status: StateStatus.success,
        items: items,
      ),
    );
    final openKey = _key;
    if (openKey == null) return;
    final labels = await vaultRepository.readLabels(items, openKey);
    // The safe locked (or opened again with another key) meanwhile: what
    // was opened before the lock is dropped, never shown or kept.
    if (isClosed ||
        !identical(state.items, items) ||
        !identical(_key, openKey)) {
      return;
    }
    emit(state.copyWith(labels: labels));
  }

  /// The safe locked (by itself, by the lock button or with the whole app):
  /// the rows' labels — usernames, file names — leave memory with the key,
  /// and a reading still under way is dropped (security review 2026-10-26).
  void forgetLabels() {
    _key = null;
    if (isClosed || state.labels.isEmpty) return;
    emit(state.copyWith(labels: const {}));
  }

  /// `null` shows every group again.
  void filterByGroup(String? groupId) {
    emit(
      VaultItemsState(
        status: state.status,
        items: state.items,
        labels: state.labels,
        selectedGroupId: groupId,
        failureType: state.failureType,
      ),
    );
  }

  Future<VaultResponse<VaultItem>> createItem(
    VaultItem item,
    VaultKey masterKey, {
    String? customPassword,
  }) async {
    emit(state.copyWith(status: StateStatus.loading));
    final res = await vaultRepository.createItem(
      item,
      masterKey,
      customPassword: customPassword,
    );
    if (res is VaultSuccess) {
      await loadItems();
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

  Future<VaultResponse<VaultItem>> updateItem(
    VaultItem item,
    VaultKey masterKey, {
    String? customPassword,
  }) async {
    emit(state.copyWith(status: StateStatus.loading));
    final res = await vaultRepository.updateItem(
      item,
      masterKey,
      customPassword: customPassword,
    );
    if (res is VaultSuccess) {
      await loadItems();
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

  Future<void> deleteItem(String itemId) async {
    emit(state.copyWith(status: StateStatus.loading));
    final res = await vaultRepository.deleteItem(itemId);
    if (res is VaultSuccess) {
      await loadItems();
    } else {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (res as VaultFailure).type,
        ),
      );
    }
  }

  Future<void> moveItemToGroup(String itemId, String newGroupId) async {
    emit(state.copyWith(status: StateStatus.loading));
    final res = await vaultRepository.moveItemToGroup(itemId, newGroupId);
    if (res is VaultSuccess) {
      await loadItems();
    } else {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (res as VaultFailure).type,
        ),
      );
    }
  }

  void autoSaveNote(
    VaultItem item,
    VaultKey masterKey, {
    String? customPassword,
  }) {
    _autoSaveDebouncer.run(() async {
      final res = await vaultRepository.updateItem(
        item,
        masterKey,
        customPassword: customPassword,
      );
      if (res is VaultSuccess) {
        final itemsRes = await vaultRepository.getAllItems();
        if (itemsRes is VaultSuccess) {
          emit(
            state.copyWith(
              items: (itemsRes as VaultSuccess<List<VaultItemMetadata>>).data,
            ),
          );
        }
      }
    });
  }

  @override
  Future<void> close() {
    _updatesSubscription.cancel();
    _autoSaveDebouncer.close();
    return super.close();
  }
}
