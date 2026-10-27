import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The state line under a [FileCard]'s name.
enum FileCardState {
  /// Nothing extra: name and size only.
  none,

  /// "Locked".
  locked,

  /// "Kept locked in My safe".
  keptInSafe,
}

/// A file: icon, name, size and its state. [trailing] holds an action such
/// as "Change". The name keeps its extension visible when it is long.
class FileCard extends StatelessWidget {
  const FileCard({
    super.key,
    required this.name,
    this.size,
    this.state = FileCardState.none,
    this.trailing,
    this.qaId,
  });

  final String name;

  /// Formatted ("3.1 MB").
  final String? size;
  final FileCardState state;
  final Widget? trailing;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final localizations = context.fuzzzyInkLocalizations;
    final stateText = switch (state) {
      FileCardState.none => null,
      FileCardState.locked => localizations.fileCardLocked,
      FileCardState.keptInSafe => localizations.fileCardKeptInSafe,
    };
    final details = [if (size != null) size!, if (stateText != null) stateText];
    final trailing = this.trailing;
    final isLocked = state != FileCardState.none;

    return Container(
      key: qaId == null ? null : Key('file.$qaId'),
      padding: context.fuzzzyDensity.panel,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(context.fuzzzyRadius.l),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              isLocked
                  ? Icons.enhanced_encryption_outlined
                  : Icons.description_outlined,
              size: context.fuzzzyIconSize.l * 1.4,
              color: colors.ink,
            ),
          ),
          SizedBox(width: space.m + space.xs / 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _middleEllipsis(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.titleS.copyWith(color: colors.ink),
                ),
                if (details.isNotEmpty)
                  Text(
                    details.join(' · '),
                    style: type.bodyS.copyWith(color: colors.inkMute),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: space.s), trailing],
        ],
      ),
    );
  }

  /// "a-very-long-holiday-photo-name.jpg.fuzz" keeps its ending.
  static String _middleEllipsis(String name) {
    const keep = 14;
    if (name.characters.length <= keep * 2 + 1) return name;
    final chars = name.characters;
    return '${chars.take(keep)}…${chars.skip(chars.length - keep)}';
  }
}
