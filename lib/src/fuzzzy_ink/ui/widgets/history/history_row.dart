import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Which way a history item went.
enum HistoryDirection {
  /// You locked it for them (filled lock, inverted box).
  locked,

  /// You opened it from them (open lock).
  opened,
}

/// One row of a person's history: what and when, never the secret itself
/// ("You locked a message · tap to read", "You opened lease.pdf · 1.2 MB ·
/// tap to see"). Read as one sentence. [highlight] tints it once: it is the
/// item that was just added.
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.direction,
    required this.time,
    required this.onTap,
    this.fileName,
    this.fileSize,
    this.highlight = false,
    required this.qaId,
  });

  final HistoryDirection direction;

  /// Already formatted for the day group ("9:20").
  final String time;
  final VoidCallback onTap;

  /// Null for a message.
  final String? fileName;

  /// Formatted ("3.1 MB"); files only.
  final String? fileSize;
  final bool highlight;
  final String qaId;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final localizations = context.fuzzzyInkLocalizations;
    final locked = direction == HistoryDirection.locked;
    final fileName = this.fileName;

    final title = switch ((locked, fileName)) {
      (true, null) => localizations.historyYouLockedMessage,
      (false, null) => localizations.historyYouOpenedMessage,
      (true, final String name) => localizations.historyYouLockedFile(name),
      (false, final String name) => localizations.historyYouOpenedFile(name),
    };
    final hint = fileName == null
        ? localizations.historyTapToRead
        : localizations.historyTapToSee;
    final subtitle = [
      if (fileName != null && fileSize != null) fileSize!,
      hint,
    ].join(' · ');

    return RowTint(
      play: highlight,
      child: Semantics(
        identifier: 'history.$qaId',
        button: true,
        container: true,
        label: '$title, $time',
        hint: hint,
        excludeSemantics: true,
        child: FuzzzyTappable(
          key: Key('history.$qaId'),
          onTap: onTap,
          focusRingInset: true,
          builder: (context, active) => Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: EdgeInsets.symmetric(
              horizontal: space.l + space.xs,
              vertical: space.m + space.xs / 2,
            ),
            decoration: BoxDecoration(
              color: active ? colors.surface : null,
              border: Border(bottom: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: locked ? colors.actionPrimaryBg : colors.surface,
                    border: Border.all(
                      color: locked ? colors.actionPrimaryBg : colors.line,
                    ),
                    borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
                  ),
                  child: Icon(
                    locked ? Icons.lock_outline : Icons.lock_open_outlined,
                    size: context.fuzzzyIconSize.l,
                    color: locked ? colors.actionPrimaryFg : colors.ink,
                  ),
                ),
                SizedBox(width: space.m + space.xs / 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleS.copyWith(color: colors.ink),
                      ),
                      SizedBox(height: space.xs / 2),
                      Text(
                        subtitle,
                        style: type.bodyS.copyWith(color: colors.inkMute),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: space.s),
                Text(time, style: type.dataS.copyWith(color: colors.inkMute)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
