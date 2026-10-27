import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// What the header's first button does.
enum FlowLeading {
  /// The back arrow (the flow goes on behind).
  back,

  /// A close cross (the flow ends here).
  close,

  /// No button (a screen that cannot be left while it works).
  none,
}

/// The one flow screen of the app (DESIGN.md section 6, "Screen recipe"),
/// used by Lock, Open, adding a person and the person's own screens: a 56 px
/// header ([FlowHeader]) with back, close or nothing and an optional title,
/// the content scrolling between 20 px margins, and the main buttons
/// anchored at the bottom in the same place on every screen.
class FlowScaffold extends StatelessWidget {
  const FlowScaffold({
    super.key,
    required this.qaId,
    required this.children,
    this.title,
    this.leading = FlowLeading.back,
    this.onLeading,
    this.actions = const [],
    this.footer,
    this.headerLine = false,
  });

  final String qaId;
  final List<Widget> children;

  /// Null leaves the header empty except for its buttons.
  final String? title;
  final FlowLeading leading;

  /// Defaults to going back.
  final VoidCallback? onLeading;
  final List<Widget> actions;

  /// The main buttons, anchored at the bottom.
  final Widget? footer;

  /// A hairline under the header.
  final bool headerLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final footer = this.footer;
    final side = space.l + space.xs;

    return Scaffold(
      key: Key('screen.$qaId'),
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlowHeader(
              qaId: qaId,
              title: title,
              leading: leading,
              onLeading: onLeading,
              actions: actions,
              line: headerLine,
            ),
            Expanded(
              child: ListView(
                key: Key('$qaId.scroll'),
                padding: EdgeInsets.fromLTRB(side, space.xs, side, space.l),
                children: children,
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.fromLTRB(side, space.m, side, space.l),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// The flows' header: back, close or nothing, a title, and actions on the
/// right.
class FlowHeader extends StatelessWidget {
  const FlowHeader({
    super.key,
    required this.qaId,
    this.title,
    this.leading = FlowLeading.back,
    this.avatar,
    this.onLeading,
    this.actions = const [],
    this.line = false,
  });

  final String qaId;
  final String? title;
  final FlowLeading leading;

  /// Shown between the back button and the title (the person's avatar).
  final Widget? avatar;
  final VoidCallback? onLeading;
  final List<Widget> actions;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final localizations = context.fuzzzyInkLocalizations;
    final title = this.title;
    final avatar = this.avatar;
    final isClose = leading == FlowLeading.close;

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: EdgeInsets.symmetric(horizontal: space.s + space.xs / 2),
      decoration: BoxDecoration(
        color: colors.ground,
        border: line ? Border(bottom: BorderSide(color: colors.line)) : null,
      ),
      child: Row(
        children: [
          if (leading != FlowLeading.none) ...[
            FuzzzyIconButton(
              icon: Icon(isClose ? Icons.close : Icons.arrow_back),
              semanticLabel: isClose ? localizations.close : localizations.back,
              qaId: '$qaId.${isClose ? 'close' : 'back'}',
              onPressed: onLeading ?? () => Navigator.of(context).maybePop(),
            ),
            SizedBox(width: space.s),
          ] else
            SizedBox(width: space.s),
          if (avatar != null) ...[avatar, SizedBox(width: space.s)],
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.fuzzzyTextStyles.titleS.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// The picture slot of a result screen: Fuzzz for [castMoment] when Fuzzzy
/// Cast is on (and the screen is not private), otherwise [glyph].
class FlowHero extends StatelessWidget {
  const FlowHero({super.key, required this.glyph, this.castMoment});

  final Widget glyph;
  final FuzzzyCastMoment? castMoment;

  @override
  Widget build(BuildContext context) {
    final moment = castMoment;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.fuzzzySpace.l),
      child: Center(
        child: moment == null
            ? glyph
            : FuzzzyCastReaction(moment: moment, fallback: glyph),
      ),
    );
  }
}

/// One title, centred, and at most one short line under it.
class FlowTitle extends StatelessWidget {
  const FlowTitle({super.key, required this.title, this.line});

  final String title;
  final String? line;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final line = this.line;
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: type.titleL.copyWith(color: colors.ink),
          ),
        ),
        if (line != null) ...[
          SizedBox(height: context.fuzzzySpace.xs),
          Text(
            line,
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: colors.inkMute),
          ),
        ],
      ],
    );
  }
}

/// A short failure line under a field or a choice; read out when it shows.
class FlowErrorLine extends StatelessWidget {
  const FlowErrorLine({super.key, required this.text, required this.qaId});

  final String? text;
  final String qaId;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    return Semantics(
      identifier: qaId,
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.only(top: context.fuzzzySpace.xs),
        child: SizedBox(
          width: double.infinity,
          child: text == null
              ? const SizedBox.shrink()
              : Text(
                  text,
                  key: Key(qaId),
                  style: context.fuzzzyTextStyles.bodyS.copyWith(
                    color: context.fuzzzyColors.errorText,
                  ),
                ),
        ),
      ),
    );
  }
}

/// "12 KB", "3.4 MB": a file's size for a file card.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value < 10 ? 1 : 0;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
