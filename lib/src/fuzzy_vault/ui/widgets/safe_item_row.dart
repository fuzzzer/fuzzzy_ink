import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The icon of a My safe item's type.
IconData safeItemIcon(VaultItemType type) => switch (type) {
      VaultItemType.password => Icons.key_outlined,
      VaultItemType.note => Icons.sticky_note_2_outlined,
      VaultItemType.file => Icons.description_outlined,
    };

/// The word for a My safe item's type ("Password", "Note", "File").
String safeItemTypeLabel(BuildContext context, VaultItemType type) {
  final localizations = context.fuzzzyInkLocalizations;
  return switch (type) {
    VaultItemType.password => localizations.vaultPasswordLabel,
    VaultItemType.note => localizations.vaultNoteLabel,
    VaultItemType.file => localizations.vaultFileLabel,
  };
}

/// An icon box for a row or a sheet door (40 px, hairline).
class SafeIconBox extends StatelessWidget {
  const SafeIconBox({super.key, required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
        ),
        child: Icon(
          icon,
          size: context.fuzzzyIconSize.l,
          color: color ?? colors.ink,
        ),
      ),
    );
  }
}

/// One My safe item in the list: type icon, title, "username · group" (a
/// file's name; the type when there is no label), chevron. Never the secret
/// itself. A long press moves it to a group.
class SafeItemRow extends StatelessWidget {
  const SafeItemRow({
    super.key,
    required this.item,
    required this.onTap,
    this.label,
    this.groupName,
    this.onLongPress,
    this.busy = false,
  });

  final VaultItemMetadata item;

  /// The item's username or file name ([VaultItemsState.labels]); null
  /// shows its type.
  final String? label;

  /// Null when the item is in no group.
  final String? groupName;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// The item is being opened: a small ring instead of the chevron.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final qaId = 'safe.item.${item.id}';
    final subtitle = [
      label ?? safeItemTypeLabel(context, item.type),
      if (groupName != null) groupName!,
    ].join(' · ');

    return Semantics(
      identifier: qaId,
      button: true,
      container: true,
      child: FuzzzyTappable(
        key: Key(qaId),
        onTap: busy ? null : onTap,
        onLongPress: busy ? null : onLongPress,
        focusRingInset: true,
        builder: (context, active) => Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: EdgeInsets.symmetric(
            horizontal: space.l,
            vertical: space.m,
          ),
          decoration: BoxDecoration(
            color: active ? colors.surface : null,
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: Row(
            children: [
              SafeIconBox(icon: safeItemIcon(item.type)),
              SizedBox(width: space.m + space.xs / 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.titleS.copyWith(color: colors.ink),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodyS.copyWith(color: colors.inkMute),
                    ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: busy
                    ? SizedBox.square(
                        dimension: context.fuzzzyIconSize.m,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.chevron_right,
                        size: context.fuzzzyIconSize.m,
                        color: colors.inkFaint,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled value on an item page ("USERNAME OR EMAIL" over the value),
/// with optional actions at its end. The value is plain, non-selectable
/// text: nothing on a My safe page can be selected out of the app.
class SafeField extends StatelessWidget {
  const SafeField({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.actions = const [],
    this.qaId,
  });

  final String label;
  final String value;
  final bool mono;
  final List<Widget> actions;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;

    return Container(
      key: qaId == null ? null : Key('safe.field.$qaId'),
      padding: EdgeInsets.symmetric(vertical: space.m),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // Georgian has no capitals: the upper-casing leaves it as is.
            label.toUpperCase(),
            style: type.label.copyWith(color: colors.inkMute),
          ),
          SizedBox(height: space.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: (mono ? type.data : type.body).copyWith(
                    color: colors.ink,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ],
      ),
    );
  }
}
