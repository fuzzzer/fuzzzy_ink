import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The Fuzzzy Ink mark, drawn in exactly one place (DESIGN.md section 11):
/// home header 26, lock screen 56, app-switcher cover 64, welcome 96, the
/// recovery-key print sheet 18, the QR screen.
///
/// It paints the chosen logo (the sun with the drop cut out, so the screen's
/// own ground shows through the drop) from `assets/logo/`, at 1x, 2x and 3x:
/// [nightAsset] on the dark look, [paperAsset] on the light look. The look
/// is read from the nearest [Theme], so a page that forces paper (the
/// printed recovery key) gets the paper mark.
class InkMark extends StatelessWidget {
  const InkMark({super.key, this.size = 26, this.qaId});

  /// The mark on the night (dark) ground, red `#b2261d`.
  static const nightAsset = 'assets/logo/ink_mark.png';

  /// The mark on the paper (light) ground, paper red `#a32218`.
  static const paperAsset = 'assets/logo/ink_mark_paper.png';

  /// The file for a look.
  static String assetFor(Brightness brightness) =>
      brightness == Brightness.dark ? nightAsset : paperAsset;

  /// Width and height; the mark is square.
  final double size;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: qaId == null ? null : 'mark.$qaId',
      label: context.fuzzzyInkLocalizations.fuzzzyInk,
      image: true,
      child: SizedBox.square(
        key: qaId == null ? null : Key('mark.$qaId'),
        dimension: size,
        child: ExcludeSemantics(
          child: Image.asset(
            assetFor(Theme.of(context).brightness),
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
