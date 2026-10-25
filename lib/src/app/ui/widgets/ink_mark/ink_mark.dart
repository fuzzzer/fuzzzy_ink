import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The Fuzzzy Ink mark, drawn in exactly one place (DESIGN.md section 11):
/// home header 26, lock screen 56, app-switcher cover 64, welcome 96, the
/// recovery-key print sheet 18, the QR screen.
///
/// Today it paints the placeholder: a plain sun disc in production red,
/// the same in both looks (the logo rules forbid the brighter red for the
/// mark).
// TODO(ink-logo): the icon branch adds the chosen drop mark under
// `assets/logo/`. Swapping is one line: set [InkMark.logoAsset] to that file
// (and list it under `flutter: assets:` if the branch has not).
class InkMark extends StatelessWidget {
  const InkMark({super.key, this.size = 26, this.qaId});

  /// Null paints the placeholder sun.
  static const String? logoAsset = null;

  /// Width and height; the mark is square.
  final double size;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    const asset = logoAsset;
    final mark = asset == null
        ? CustomPaint(
            size: Size.square(size),
            painter: const _PlaceholderSunPainter(),
          )
        : Image.asset(asset, width: size, height: size);

    return Semantics(
      identifier: qaId == null ? null : 'mark.$qaId',
      label: context.fuzzzyInkLocalizations.fuzzzyInk,
      image: true,
      child: SizedBox.square(
        key: qaId == null ? null : Key('mark.$qaId'),
        dimension: size,
        child: ExcludeSemantics(child: mark),
      ),
    );
  }
}

class _PlaceholderSunPainter extends CustomPainter {
  const _PlaceholderSunPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      Paint()..color = FuzzzyPalette.r600,
    );
  }

  @override
  bool shouldRepaint(_PlaceholderSunPainter oldDelegate) => false;
}
