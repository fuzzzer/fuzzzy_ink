import 'package:flutter/material.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:qr/qr.dart';

/// [data] drawn as a square QR code, offline (package `qr`). Modules take
/// the darker of the theme's ink and ground, the quiet zone the lighter, so
/// the code is dark on light in every skin, as camera apps expect.
class QrCodeView extends StatelessWidget {
  const QrCodeView({super.key, required this.data, this.semanticLabel});

  final String data;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final inkIsDarker =
        colors.ink.computeLuminance() < colors.ground.computeLuminance();

    return Semantics(
      label: semanticLabel,
      image: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _QrCodePainter(
            image: QrImage(
              QrCode.fromData(
                data: data,
                errorCorrectLevel: QrErrorCorrectLevel.L,
              ),
            ),
            dark: inkIsDarker ? colors.ink : colors.ground,
            light: inkIsDarker ? colors.ground : colors.ink,
          ),
        ),
      ),
    );
  }
}

class _QrCodePainter extends CustomPainter {
  _QrCodePainter({
    required this.image,
    required this.dark,
    required this.light,
  });

  /// The quiet zone the QR standard asks for, in modules.
  static const _quietModules = 4;

  final QrImage image;
  final Color dark;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final module = size.shortestSide / (count + 2 * _quietModules);
    canvas.drawRect(Offset.zero & size, Paint()..color = light);

    final darkPaint = Paint()..color = dark;
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (col + _quietModules) * module,
            (row + _quietModules) * module,
            // A hair wider, so neighbours never show a seam between them.
            module + 0.5,
            module + 0.5,
          ),
          darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrCodePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.dark != dark ||
      oldDelegate.light != light;
}
