import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A screen of the people flows (DESIGN.md section 6, "Screen recipe"): a
/// 56 px header with back (or close) and an optional title, the content
/// scrolling between 20 px margins, and the main buttons anchored at the
/// bottom in the same place on every screen.
class InkFlowScaffold extends StatelessWidget {
  const InkFlowScaffold({
    super.key,
    required this.qaId,
    required this.children,
    this.title,
    this.close = false,
    this.onLeading,
    this.actions = const [],
    this.footer,
    this.headerLine = false,
  });

  final String qaId;
  final List<Widget> children;

  /// Null leaves the header empty except for its buttons.
  final String? title;

  /// A close cross instead of the back arrow (the flow ends here).
  final bool close;

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
            InkFlowHeader(
              qaId: qaId,
              title: title,
              close: close,
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

/// The flows' header: back or close, a title, and actions on the right.
class InkFlowHeader extends StatelessWidget {
  const InkFlowHeader({
    super.key,
    required this.qaId,
    this.title,
    this.leading,
    this.close = false,
    this.onLeading,
    this.actions = const [],
    this.line = false,
  });

  final String qaId;
  final String? title;

  /// Shown between the back button and the title (the person's avatar).
  final Widget? leading;
  final bool close;
  final VoidCallback? onLeading;
  final List<Widget> actions;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final localizations = context.fuzzzyInkLocalizations;
    final title = this.title;
    final leading = this.leading;

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: EdgeInsets.symmetric(horizontal: space.s + space.xs / 2),
      decoration: BoxDecoration(
        color: colors.ground,
        border: line ? Border(bottom: BorderSide(color: colors.line)) : null,
      ),
      child: Row(
        children: [
          FuzzzyIconButton(
            icon: Icon(close ? Icons.close : Icons.arrow_back),
            semanticLabel: close ? localizations.close : localizations.back,
            qaId: '$qaId.${close ? 'close' : 'back'}',
            onPressed: onLeading ?? () => Navigator.of(context).maybePop(),
          ),
          SizedBox(width: space.s),
          if (leading != null) ...[leading, SizedBox(width: space.s)],
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

/// The big picture slot of a result screen (132 px tall): Fuzzz for
/// [moment] when Fuzzzy Cast is on, otherwise [glyph].
class InkHeroSlot extends StatelessWidget {
  const InkHeroSlot({
    super.key,
    required this.glyph,
    this.moment,
    this.qaId,
  });

  final Widget glyph;

  /// Null: never Fuzzz here (a security warning).
  final FuzzzyCastMoment? moment;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final moment = this.moment;
    return SizedBox(
      height: 132,
      child: Center(
        child: moment == null
            ? glyph
            : FuzzzyCastReaction(moment: moment, qaId: qaId, fallback: glyph),
      ),
    );
  }
}

/// A centred screen title (the large one on result screens).
class InkScreenTitle extends StatelessWidget {
  const InkScreenTitle(this.text, {super.key, this.large = false});

  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final type = context.fuzzzyTextStyles;
    return Semantics(
      header: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: (large ? type.displayL : type.titleL).copyWith(
          color: context.fuzzzyColors.ink,
        ),
      ),
    );
  }
}

/// One short muted line under a title.
class InkScreenLine extends StatelessWidget {
  const InkScreenLine(this.text, {super.key, this.center = true});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: context.fuzzzyTextStyles.body.copyWith(
        color: context.fuzzzyColors.inkMute,
      ),
    );
  }
}
