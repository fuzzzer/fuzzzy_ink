import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:uuid/uuid.dart';

class VaultGroupFilter extends StatelessWidget {
  const VaultGroupFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VaultGroupsCubit, VaultGroupsState>(
      builder: (context, groupsState) {
        return BlocBuilder<VaultItemsCubit, VaultItemsState>(
          builder: (context, itemsState) {
            final selectedGroupId = itemsState.selectedGroupId;

            return SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _GroupChip(
                    title: currentContextLocalization.vaultAll,
                    isSelected: selectedGroupId == null,
                    onTap: () =>
                        context.read<VaultItemsCubit>().filterByGroup(null),
                  ),
                  const SizedBox(width: 8),
                  ...groupsState.groups.map((g) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _GroupChip(
                        title: g.name,
                        icon: _getIconForGroup(g.name),
                        isSelected: selectedGroupId == g.id,
                        onTap: () =>
                            context.read<VaultItemsCubit>().filterByGroup(g.id),
                      ),
                    );
                  }),
                  _GroupChip(
                    title: currentContextLocalization.vaultAddGroup,
                    icon: Icons.add,
                    isSelected: false,
                    onTap: () => _showAddGroupDialog(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddGroupDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.fuzzzyColors.surface,
          title: Text(
            currentContextLocalization.vaultNewGroup,
            style: TextStyle(color: context.fuzzzyColors.ink),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: TextStyle(color: context.fuzzzyColors.ink),
            decoration: InputDecoration(
              hintText: currentContextLocalization.vaultGroupName,
              hintStyle: TextStyle(color: context.fuzzzyColors.inkMute),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.fuzzzyColors.inkMute),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.fuzzzyColors.focusBorder),
              ),
            ),
            onSubmitted: (_) =>
                _submitGroup(context, dialogContext, nameController),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: context.fuzzzyColors.inkMute,
              ),
              child: Text(currentContextLocalization.cancel),
            ),
            TextButton(
              onPressed: () =>
                  _submitGroup(context, dialogContext, nameController),
              style: TextButton.styleFrom(
                foregroundColor: context.fuzzzyColors.ink,
              ),
              child: Text(currentContextLocalization.create),
            ),
          ],
        );
      },
    );
  }

  void _submitGroup(
    BuildContext parentContext,
    BuildContext dialogContext,
    TextEditingController nameController,
  ) {
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final now = DateTime.now();
    final group = VaultGroupData(
      id: const Uuid().v4(),
      name: name,
      emoji: '📁',
      colorIndex: 0,
      sortOrder: 0,
      hasCustomPassword: false,
      createdAt: now,
      updatedAt: now,
    );

    parentContext.read<VaultGroupsCubit>().createGroup(group);
    Navigator.of(dialogContext).pop();
  }

  IconData _getIconForGroup(String name) {
    final n = name.toLowerCase();
    if (n.contains('work')) return Icons.work_outline;
    if (n.contains('home')) return Icons.home_outlined;
    if (n.contains('bank') || n.contains('finance')) {
      return Icons.account_balance_outlined;
    }
    return Icons.folder_outlined;
  }
}

class _GroupChip extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _GroupChip({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? context.fuzzzyColors.ground
              : context.fuzzzyColors.ink,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isSelected
                  ? context.fuzzzyColors.ground
                  : context.fuzzzyColors.ink,
            )
          : null,
      backgroundColor: isSelected
          ? context.fuzzzyColors.actionPrimaryBg
          : context.fuzzzyColors.surface,
      onPressed: onTap,
    );
  }
}
