import 'dart:async';
import 'package:flutter/services.dart';
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
  Timer? _clipboardClearTimer;
  final Debouncer _autoSaveDebouncer = Debouncer(milliseconds: 2000);

  Future<void> loadItems() async {
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
  }

  void filterByGroup(String? groupId) {
    emit(state.copyWith(selectedGroupId: groupId));
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

  Future<void> copyToClipboard(
    String text, {
    int clearAfterSeconds = 45,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));

    _clipboardClearTimer?.cancel();
    if (clearAfterSeconds > 0) {
      _clipboardClearTimer =
          Timer(Duration(seconds: clearAfterSeconds), () async {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text == text) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      });
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
    _clipboardClearTimer?.cancel();
    _updatesSubscription.cancel();
    _autoSaveDebouncer.close();
    return super.close();
  }
}
