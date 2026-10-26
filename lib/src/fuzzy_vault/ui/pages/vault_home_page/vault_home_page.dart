import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// The four switches of the open My safe, in order.
enum SafeFilter { all, passwords, notes, files }

/// My safe, open (DESIGN.md section 4.11): search, All · Passwords · Notes ·
/// Files, group chips with New group, the items (title and type only, never
/// the secret), "Locks itself after 5 minutes away" and the Add button
/// (Password · Note · File). The header with the lock is the shell's.
class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key});

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  late SafeFilter _filter;
  String? _openingId;

  @override
  void initState() {
    super.initState();
    final saved = sl.get<PreferencesService>().vaultLastSelectedTabIndex;
    _filter = SafeFilter.values[saved.clamp(0, SafeFilter.values.length - 1)];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VaultItemsCubit>().loadItems();
      context.read<VaultGroupsCubit>().loadGroups();
    });
  }

  void _select(SafeFilter filter) {
    setState(() => _filter = filter);
    unawaited(
      sl.get<PreferencesService>().setVaultLastSelectedTabIndex(filter.index),
    );
  }

  bool _matches(VaultItemMetadata item) => switch (_filter) {
        SafeFilter.all => true,
        SafeFilter.passwords => item.type == VaultItemType.password,
        SafeFilter.notes => item.type == VaultItemType.note,
        SafeFilter.files => item.type == VaultItemType.file,
      };

  Future<void> _openItem(VaultItemMetadata item) async {
    final masterKey = context.read<VaultAuthCubit>().state.masterKey;
    if (masterKey == null) return;
    setState(() => _openingId = item.id);
    final res = await sl.get<VaultRepository>().getItem(item.id, masterKey);
    if (!mounted) return;
    setState(() => _openingId = null);
    if (res is! VaultSuccess<VaultItem>) {
      showInkToast(
        context,
        message: context.fuzzzyInkLocalizations.safeItemLoadFailed,
        kind: FuzzzyToastKind.error,
      );
      return;
    }
    await context.push(AppRouter.vaultItem, extra: res.data);
  }

  Future<void> _add() async {
    final type = await showSafeAddSheet(context);
    if (type == null || !mounted) return;
    final groupId = context.read<VaultItemsCubit>().state.selectedGroupId ??
        VaultGroupData.generalGroupId;
    final saved = await context.push<VaultItem>(
      AppRouter.vaultItemEditor,
      extra: VaultItemEditorPagePayload(type: type, groupId: groupId),
    );
    if (saved == null || !mounted) return;
    showInkToast(
      context,
      message: context.fuzzzyInkLocalizations.safeSaved,
      qaId: 'safe.saved',
    );
  }

  Future<void> _move(VaultItemMetadata item) async {
    final groups = context.read<VaultGroupsCubit>().state.groups;
    final groupId = await showSafeMoveSheet(
      context,
      groups: groups,
      currentGroupId: item.groupId,
    );
    if (groupId == null || groupId == item.groupId || !mounted) return;
    await context.read<VaultItemsCubit>().moveItemToGroup(item.id, groupId);
    if (!mounted) return;
    final localizations = context.fuzzzyInkLocalizations;
    final name = _groupName(groups, groupId);
    showInkToast(
      context,
      message: name == null
          ? localizations.safeMovedOut
          : localizations.safeMovedTo(name),
    );
  }

  Future<void> _newGroup() async {
    final name = await showSafeNewGroupSheet(context);
    if (name == null || !mounted) return;
    final now = DateTime.now();
    final res = await context.read<VaultGroupsCubit>().createGroup(
          VaultGroupData(
            id: const Uuid().v4(),
            name: name,
            emoji: '',
            colorIndex: 0,
            sortOrder: 0,
            hasCustomPassword: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (!mounted) return;
    if (res is VaultSuccess<VaultGroupData>) {
      context.read<VaultItemsCubit>().filterByGroup(res.data.id);
    }
  }

  /// A group's name, or null for the general group ("No group").
  static String? _groupName(List<VaultGroupData> groups, String groupId) {
    if (groupId == VaultGroupData.generalGroupId) return null;
    for (final group in groups) {
      if (group.id == groupId) return group.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(space.l, space.s, space.l, 0),
              child: FuzzzyTextField(
                hint: localizations.safeSearch,
                leadingIcon: const Icon(Icons.search),
                qaId: 'safe.search',
                onChanged: context.read<VaultSearchCubit>().updateQuery,
              ),
            ),
            SizedBox(height: space.m),
            // The kit control keeps each label whole: where four labels do
            // not fit (Georgian, large text) it scrolls sideways.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: space.l),
              child: FuzzzySegmentedControl(
                qaId: 'safe.filter',
                segments: [
                  localizations.vaultAll,
                  localizations.vaultPasswords,
                  localizations.vaultNotes,
                  localizations.vaultFiles,
                ],
                selectedIndex: _filter.index,
                onChanged: (index) => _select(SafeFilter.values[index]),
              ),
            ),
            SizedBox(height: space.m),
            _GroupChips(onNewGroup: _newGroup),
            SizedBox(height: space.s),
            Expanded(child: _list(context)),
          ],
        ),
        PositionedDirectional(
          end: space.l,
          bottom: space.l,
          child: FuzzzyButton(
            label: localizations.safeAdd,
            icon: const Icon(Icons.add),
            qaId: 'safe.add',
            onPressed: _add,
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    return BlocBuilder<VaultSearchCubit, VaultSearchState>(
      builder: (context, search) {
        return BlocBuilder<VaultGroupsCubit, VaultGroupsState>(
          builder: (context, groupsState) {
            return BlocBuilder<VaultItemsCubit, VaultItemsState>(
              builder: (context, itemsState) {
                final isSearch = search.query.trim().isNotEmpty;
                final source = isSearch ? search.results : itemsState.items;
                final groupId = itemsState.selectedGroupId;
                final items = source
                    .where(_matches)
                    .where((i) => groupId == null || i.groupId == groupId)
                    .toList();
                final isLoading = isSearch
                    ? search.status == StateStatus.loading
                    : itemsState.status == StateStatus.loading ||
                        itemsState.status == StateStatus.initial;

                if (items.isEmpty) {
                  if (isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (!isSearch && itemsState.status == StateStatus.failed) {
                    return _Empty(
                      title: context.fuzzzyInkLocalizations.safeLoadError,
                      qaId: 'safe.loadError',
                    );
                  }
                  return _Empty(
                    icon: isSearch ? Icons.search : Icons.shield_outlined,
                    title: isSearch
                        ? context.fuzzzyInkLocalizations.safeNothingFound
                        : context.fuzzzyInkLocalizations.safeEmptyTitle,
                    message: isSearch
                        ? context.fuzzzyInkLocalizations.safeTryAnotherWord
                        : context.fuzzzyInkLocalizations.safeEmptyLine,
                    qaId: isSearch ? 'safe.nothingFound' : 'safe.empty',
                  );
                }

                return ListView.builder(
                  key: const Key('safe.list'),
                  padding: EdgeInsets.only(bottom: context.fuzzzySpace.xxl * 2),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == items.length) return const _AutoLockTip();
                    final item = items[index];
                    return SafeItemRow(
                      key: ValueKey(item.id),
                      item: item,
                      groupName: _groupName(groupsState.groups, item.groupId),
                      busy: _openingId == item.id,
                      onTap: () => _openItem(item),
                      onLongPress: () => _move(item),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// All groups · each group · New group. The general group is "No group" and
/// gets no chip of its own.
class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.onNewGroup});

  final VoidCallback onNewGroup;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final groups = context
        .watch<VaultGroupsCubit>()
        .state
        .groups
        .where((g) => g.id != VaultGroupData.generalGroupId)
        .toList();
    final selected = context.select<VaultItemsCubit, String?>(
      (cubit) => cubit.state.selectedGroupId,
    );
    final items = context.read<VaultItemsCubit>();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: space.l),
        children: [
          FuzzzyFilterChip(
            label: localizations.safeAllGroups,
            selected: selected == null,
            qaId: 'safe.group.all',
            onTap: () => items.filterByGroup(null),
          ),
          for (final group in groups) ...[
            SizedBox(width: space.s),
            FuzzzyFilterChip(
              label: group.name,
              leadingIcon: const Icon(Icons.folder_outlined),
              selected: selected == group.id,
              qaId: 'safe.group.${group.id}',
              onTap: () => items.filterByGroup(group.id),
            ),
          ],
          SizedBox(width: space.s),
          FuzzzyFilterChip(
            label: localizations.safeNewGroup,
            leadingIcon: const Icon(Icons.add),
            qaId: 'safe.group.new',
            onTap: onNewGroup,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.qaId,
    this.message,
    this.icon = Icons.info_outline,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String qaId;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final message = this.message;

    return ListView(
      key: Key(qaId),
      padding: EdgeInsets.all(space.l),
      children: [
        SizedBox(height: space.xl),
        ExcludeSemantics(
          child: Icon(
            icon,
            size: context.fuzzzyIconSize.l * 1.4,
            color: colors.inkMute,
          ),
        ),
        SizedBox(height: space.s),
        Text(
          title,
          textAlign: TextAlign.center,
          style: type.titleS.copyWith(color: colors.ink),
        ),
        if (message != null)
          Text(
            message,
            textAlign: TextAlign.center,
            style: type.bodyS.copyWith(color: colors.inkMute),
          ),
        const _AutoLockTip(),
      ],
    );
  }
}

/// "Locks itself after 5 minutes away".
class _AutoLockTip extends StatelessWidget {
  const _AutoLockTip();

  @override
  Widget build(BuildContext context) {
    final space = context.fuzzzySpace;
    return Padding(
      padding: EdgeInsets.fromLTRB(space.l, space.l, space.l, 0),
      child: Center(
        child: TipLine(
          icon: Icons.schedule,
          text: context.fuzzzyInkLocalizations.safeAutoLockTip(
            VaultAuthCubit.autoLockAfter.inMinutes,
          ),
          qaId: 'safe.autoLock',
        ),
      ),
    );
  }
}
