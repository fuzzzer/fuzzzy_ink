import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

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
