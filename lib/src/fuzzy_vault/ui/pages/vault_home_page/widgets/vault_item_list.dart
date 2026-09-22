import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

class VaultItemList extends StatelessWidget {
  final VaultItemType? filterType;

  const VaultItemList({super.key, this.filterType});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VaultSearchCubit, VaultSearchState>(
      builder: (context, searchState) {
        if (searchState.query.isNotEmpty) {
          if (searchState.status == StateStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          var results = searchState.results;
          if (filterType != null) {
            results = results.where((i) => i.type == filterType).toList();
          }

          if (results.isEmpty) {
            return _EmptyState(filterType: filterType, isSearch: true);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return VaultItemCard(itemMetadata: results[index]);
            },
          );
        }

        return BlocBuilder<VaultItemsCubit, VaultItemsState>(
          builder: (context, itemsState) {
            if (itemsState.status == StateStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            var items = itemsState.items;
            if (filterType != null) {
              items = items.where((i) => i.type == filterType).toList();
            }
            if (itemsState.selectedGroupId != null) {
              items = items
                  .where((i) => i.groupId == itemsState.selectedGroupId)
                  .toList();
            }

            if (items.isEmpty) {
              return _EmptyState(filterType: filterType);
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return VaultItemCard(itemMetadata: items[index]);
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VaultItemType? filterType;
  final bool isSearch;

  const _EmptyState({this.filterType, this.isSearch = false});

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;

    if (isSearch) {
      message = currentContextLocalization.vaultNoResultsFound;
      icon = Icons.search_off_rounded;
    } else if (filterType == VaultItemType.password) {
      message = currentContextLocalization.vaultNoPasswordsYet;
      icon = Icons.key_off_rounded;
    } else if (filterType == VaultItemType.note) {
      message = currentContextLocalization.vaultNoNotesYet;
      icon = Icons.note_outlined;
    } else if (filterType == VaultItemType.file) {
      message = currentContextLocalization.vaultNoFilesYet;
      icon = Icons.file_copy_outlined;
    } else {
      message = currentContextLocalization.vaultIsEmpty;
      icon = Icons.lock_outline;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: context.fuzzzyColors.inkMute),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.fuzzzyColors.inkMute),
          ),
        ],
      ),
    );
  }
}

class VaultItemCard extends StatefulWidget {
  final VaultItemMetadata itemMetadata;

  const VaultItemCard({super.key, required this.itemMetadata});

  @override
  State<VaultItemCard> createState() => _VaultItemCardState();
}

class _VaultItemCardState extends State<VaultItemCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.itemMetadata.type == VaultItemType.password;
    final isFile = widget.itemMetadata.type == VaultItemType.file;
    final icon = isPassword
        ? Icons.key_rounded
        : isFile
            ? Icons.file_present_rounded
            : Icons.notes_rounded;
    final title = widget.itemMetadata.title;

    return Container(
      decoration: BoxDecoration(
        color: context.fuzzzyColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: context.fuzzzyColors.ink),
        title: Text(
          title,
          style: TextStyle(
            color: context.fuzzzyColors.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          isPassword
              ? currentContextLocalization.vaultPasswordLabel
              : isFile
                  ? currentContextLocalization.vaultFileLabel
                  : currentContextLocalization.vaultNoteLabel,
          style: TextStyle(color: context.fuzzzyColors.inkMute),
        ),
        trailing: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: Icon(
                  Icons.copy,
                  color: context.fuzzzyColors.inkMute,
                ),
                onPressed: () {
                  // Need to fetch full item and decrypt to copy. For now just placeholder
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        currentContextLocalization.vaultCopyingNotImplemented,
                      ),
                    ),
                  );
                },
              ),
        onTap: _isLoading
            ? null
            : () async {
                setState(() => _isLoading = true);
                try {
                  // Fetch the full item using the repository, then pass to editor
                  final masterKey =
                      context.read<VaultAuthCubit>().state.masterKey;
                  if (masterKey == null) return;

                  final repo = sl.get<VaultRepository>();
                  final res =
                      await repo.getItem(widget.itemMetadata.id, masterKey);

                  if (res is VaultSuccess && context.mounted) {
                    await context.push(
                      AppRouter.vaultItemEditor,
                      extra: VaultItemEditorPagePayload(
                        type: widget.itemMetadata.type,
                        existingItem: (res as VaultSuccess<VaultItem>).data,
                      ),
                    );
                    if (context.mounted) {
                      await context.read<VaultItemsCubit>().loadItems();
                    }
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          currentContextLocalization.vaultFailedToLoadItem,
                        ),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
        onLongPress: _isLoading ? null : () => _showMoveToGroupSheet(context),
      ),
    );
  }

  void _showMoveToGroupSheet(BuildContext context) {
    final groups = context.read<VaultGroupsCubit>().state.groups;
    final currentGroupId = widget.itemMetadata.groupId;
    final localizations = context.fuzzzySealLocalizations;
    final fuzzzyColors = context.fuzzzyColors;
    final titleStyle = context.fuzzzyTextStyles.titleM.copyWith(
      color: fuzzzyColors.ink,
    );

    final otherGroups = groups.where((g) => g.id != currentGroupId).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: fuzzzyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        final children = <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              localizations.vaultMoveToGroup,
              style: titleStyle,
            ),
          ),
        ];

        if (otherGroups.isEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                localizations.vaultNoOtherGroups,
                style: TextStyle(color: fuzzzyColors.inkMute),
              ),
            ),
          );
        } else {
          for (final group in otherGroups) {
            children.add(
              ListTile(
                leading: Icon(
                  Icons.folder_outlined,
                  color: fuzzzyColors.ink,
                ),
                title: Text(
                  group.name,
                  style: TextStyle(color: fuzzzyColors.ink),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  context.read<VaultItemsCubit>().moveItemToGroup(
                        widget.itemMetadata.id,
                        group.id,
                      );
                },
              ),
            );
          }
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );
      },
    );
  }
}
