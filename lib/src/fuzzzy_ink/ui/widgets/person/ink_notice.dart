import 'package:flutter/material.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// What an [InkNotice] says.
enum InkNoticeKind {
  /// A fact that went right ("The invite is good.").
  ok,

  /// Something to do soon ("Not checked yet. Check numbers.").
  warning,

  /// A safety warning ("Don't lock anything for Tamar yet.").
  danger,
}

/// A short note with a 3 px rule on its left, a soft tint and an icon: a
/// bold [lead] followed by the rest of the sentence ([text]). With [onTap]
/// it is a button and shows a chevron. Words and an icon carry the meaning,
/// never the colour alone.
class InkNotice extends StatelessWidget {
  const InkNotice({
    super.key,
    required this.kind,
    this.lead,
    this.text,
    this.onTap,
    this.qaId,
  });

  final InkNoticeKind kind;
  final String? lead;
  final String? text;
  final VoidCallback? onTap;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final (Color tint, IconData icon) = switch (kind) {
      InkNoticeKind.ok => (colors.success, Icons.check),
      InkNoticeKind.warning => (colors.warning, Icons.shield_outlined),
      InkNoticeKind.danger => (colors.destructive, Icons.warning_amber),
    };
    final style = type.bodyS.copyWith(color: colors.ink);
    final lead = this.lead;
    final text = this.text;
    final onTap = this.onTap;
    final sentence = [if (lead != null) lead, if (text != null) text].join(' ');

    final body = Container(
      key: qaId == null ? null : Key('notice.$qaId'),
      padding: context.fuzzzyDensity.notice,
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.12), colors.surface),
        border: Border(left: BorderSide(color: tint, width: 3)),
        borderRadius: BorderRadius.circular(context.fuzzzyRadius.s),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.fuzzzyIconSize.l, color: tint),
          SizedBox(width: space.m),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (lead != null)
                    TextSpan(
                      text: lead,
                      style: style.copyWith(fontWeight: FontWeight.w600),
                    ),
                  if (lead != null && text != null) const TextSpan(text: ' '),
                  if (text != null) TextSpan(text: text),
                ],
              ),
              style: style,
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: context.fuzzzyIconSize.m,
              color: colors.inkMute,
            ),
        ],
      ),
    );

    return Semantics(
      identifier: qaId == null ? null : 'notice.$qaId',
      container: true,
      button: onTap != null,
      label: sentence,
      excludeSemantics: true,
      child: onTap == null
          ? body
          : FuzzzyTappable(
              onTap: onTap,
              builder: (context, active) =>
                  Opacity(opacity: active ? 0.85 : 1, child: body),
            ),
    );
  }
}
