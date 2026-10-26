import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The screen recipe of the Lock and Open flows (DESIGN.md section 6): a
/// header with back or close, the content scrolling under it, and the main
/// button anchored at the bottom in the same place on every screen.
class InkFlowScaffold extends StatelessWidget {
  const InkFlowScaffold({
    super.key,
    required this.qaId,
    required this.body,
    this.title = '',
    this.onLeading,
    this.isClose = false,
    this.footer,
  });

  final String qaId;
  final String title;

  /// Back (or close, with [isClose]); none when null.
  final VoidCallback? onLeading;
  final bool isClose;
  final Widget body;

  /// The main button(s) at the bottom.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final padding = context.fuzzzyDensity.screen;
    final localizations = context.fuzzzyInkLocalizations;
    final leading = onLeading;

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding.left / 2),
              child: FuzzzyAppBar(
                title: title,
                qaId: '$qaId.appbar',
                leading: leading == null
                    ? null
                    : Semantics(
                        label:
                            isClose ? localizations.close : localizations.back,
                        child: Icon(isClose ? Icons.close : Icons.arrow_back),
                      ),
                onLeading: leading,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: Key('$qaId.scroll'),
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  context.fuzzzySpace.s,
                  padding.right,
                  context.fuzzzySpace.l,
                ),
                child: body,
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  context.fuzzzySpace.s,
                  padding.right,
                  context.fuzzzySpace.m,
                ),
                child: footer,
              ),
          ],
        ),
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
