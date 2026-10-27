part of 'vault_items_cubit.dart';

class VaultItemsState {
  const VaultItemsState({
    this.status = StateStatus.initial,
    this.items = const [],
    this.selectedGroupId,
    this.failureType,
    this.labels = const {},
  });

  final StateStatus status;
  final List<VaultItemMetadata> items;
  final String? selectedGroupId;
  final VaultFailureType? failureType;

  /// Item id → what the row shows under the title (a username, a file
  /// name); an item without one shows its type.
  final Map<String, String> labels;

  VaultItemsState copyWith({
    StateStatus? status,
    List<VaultItemMetadata>? items,
    String? selectedGroupId,
    VaultFailureType? failureType,
    Map<String, String>? labels,
  }) {
    return VaultItemsState(
      status: status ?? this.status,
      items: items ?? this.items,
      labels: labels ?? this.labels,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      failureType: failureType ??
          (status == StateStatus.success ? null : this.failureType),
    );
  }
}
