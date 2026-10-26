import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Add to My safe": Password · Note · File. Answers the chosen type.
Future<VaultItemType?> showSafeAddSheet(BuildContext context) {
  final localizations = context.fuzzzyInkLocalizations;
  return FuzzzyBottomSheet.show<VaultItemType>(
    context,
    qaId: 'safe.add',
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: 'safe.add',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeSheetTitle(localizations.safeAddTitle),
          for (final type in VaultItemType.values)
            SafeSheetRow(
              qaId: 'safe.add.${type.name}',
              icon: safeItemIcon(type),
              title: safeItemTypeLabel(sheetContext, type),
              divider: type != VaultItemType.values.last,
              onTap: () => Navigator.of(sheetContext).pop(type),
            ),
        ],
      ),
    ),
  );
}

/// What the item's More menu was asked to do.
enum SafeItemMenuChoice { move, delete }

/// An item's More menu: Move to a group · Delete.
Future<SafeItemMenuChoice?> showSafeItemMenu(BuildContext context) {
  final localizations = context.fuzzzyInkLocalizations;
  return FuzzzyBottomSheet.show<SafeItemMenuChoice>(
    context,
    qaId: 'safe.menu',
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: 'safe.menu',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeSheetRow(
            qaId: 'safe.menu.move',
            icon: Icons.folder_outlined,
            title: localizations.safeMoveToGroup,
            onTap: () =>
                Navigator.of(sheetContext).pop(SafeItemMenuChoice.move),
          ),
          SafeSheetRow(
            qaId: 'safe.menu.delete',
            icon: Icons.delete_outline,
            title: localizations.delete,
            danger: true,
            divider: false,
            onTap: () =>
                Navigator.of(sheetContext).pop(SafeItemMenuChoice.delete),
          ),
        ],
      ),
    ),
  );
}

/// "Move to a group": No group, then every group; the current one is
/// ticked. Answers the chosen group's id (the general group is "No group").
Future<String?> showSafeMoveSheet(
  BuildContext context, {
  required List<VaultGroupData> groups,
  required String currentGroupId,
}) {
  final localizations = context.fuzzzyInkLocalizations;
  final choices = [
    (id: VaultGroupData.generalGroupId, name: localizations.safeNoGroup),
    for (final group in groups)
      if (group.id != VaultGroupData.generalGroupId)
        (id: group.id, name: group.name),
  ];

  return FuzzzyBottomSheet.show<String>(
    context,
    qaId: 'safe.move',
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: 'safe.move',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeSheetTitle(localizations.safeMoveToGroup),
          for (final choice in choices)
            SafeSheetRow(
              qaId: 'safe.move.${choice.id}',
              icon: Icons.folder_outlined,
              title: choice.name,
              selected: choice.id == currentGroupId,
              divider: choice != choices.last,
              onTap: () => Navigator.of(sheetContext).pop(choice.id),
            ),
        ],
      ),
    ),
  );
}

/// "New group": a name and Add group. Answers the trimmed name.
Future<String?> showSafeNewGroupSheet(BuildContext context) {
  return FuzzzyBottomSheet.show<String>(
    context,
    qaId: 'safe.newGroup',
    builder: (_) => const _NewGroupSheet(),
  );
}

class _NewGroupSheet extends StatefulWidget {
  const _NewGroupSheet();

  @override
  State<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends State<_NewGroupSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return FuzzzyBottomSheet(
      qaId: 'safe.newGroup',
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeSheetTitle(localizations.safeNewGroup),
            SizedBox(height: space.s),
            VaultPlaintextField(
              controller: _controller,
              label: localizations.safeGroupName,
              hint: localizations.safeGroupHint,
              autofocus: true,
              onSubmitted: _add,
              qaId: 'safe.newGroup.name',
            ),
            SizedBox(height: space.l),
            FuzzzyButton(
              label: localizations.safeAddGroup,
              qaId: 'safe.newGroup.add',
              onPressed: _controller.text.trim().isEmpty ? null : _add,
            ),
          ],
        ),
      ),
    );
  }
}

/// A sheet's title.
class SafeSheetTitle extends StatelessWidget {
  const SafeSheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.fuzzzySpace.s),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: context.fuzzzyTextStyles.titleL.copyWith(
            color: context.fuzzzyColors.ink,
          ),
        ),
      ),
    );
  }
}

/// A row in a My safe sheet: icon box, title, then a chevron, or a check when
/// [selected]. [danger] paints it in the destructive text colour.
class SafeSheetRow extends StatelessWidget {
  const SafeSheetRow({
    super.key,
    required this.qaId,
    required this.icon,
    required this.title,
    required this.onTap,
    this.selected = false,
    this.danger = false,
    this.divider = true,
  });

  final String qaId;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool selected;
  final bool danger;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final color = danger ? colors.destructiveText : colors.ink;

    return Semantics(
      identifier: qaId,
      button: true,
      selected: selected,
      container: true,
      child: FuzzzyTappable(
        key: Key(qaId),
        onTap: onTap,
        focusRingInset: true,
        builder: (context, active) => Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: EdgeInsets.symmetric(vertical: space.m),
          decoration: BoxDecoration(
            color: active ? colors.surface : null,
            border:
                divider ? Border(bottom: BorderSide(color: colors.line)) : null,
          ),
          child: Row(
            children: [
              SafeIconBox(icon: icon, color: color),
              SizedBox(width: space.m + space.xs / 2),
              Expanded(
                child: Text(
                  title,
                  style: context.fuzzzyTextStyles.titleS.copyWith(
                    color: color,
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  selected ? Icons.check : Icons.chevron_right,
                  size: context.fuzzzyIconSize.m,
                  color: selected ? colors.ink : colors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
