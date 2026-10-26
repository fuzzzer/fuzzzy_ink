import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// iPhone and iPad from iOS 16: the system's own Paste button
/// (`UIPasteControl`, `InkPasteButton` in the runner). A paste through it
/// never asks "Allow Paste?", because iOS draws the button and sees the
/// person's tap (final regression 2026-10-26). It is greyed while the
/// clipboard holds nothing to paste. Elsewhere [isAvailable] is false and
/// the caller reads the clipboard on its own tap, as before.
///
/// The button's word ("Paste") is the system's, in the phone's language.
class InkPasteButton extends StatefulWidget {
  const InkPasteButton({
    super.key,
    required this.onPasted,
    required this.qaId,
  });

  /// The text pasted, trimmed; empty when the clipboard held no text.
  final ValueChanged<String> onPasted;
  final String qaId;

  static const viewType = 'com.fuzzzycore.ink/paste_button';

  /// The button's size: the system draws the clipboard icon and "Paste".
  static const size = Size(108, 40);

  /// Tests set it; null asks the device.
  @visibleForTesting
  static bool? debugIsAvailable;

  static bool get isAvailable =>
      debugIsAvailable ??
      (!kIsWeb &&
          Platform.isIOS &&
          iosMajorVersion(Platform.operatingSystemVersion) >= 16);

  /// "Version 26.5 (Build 23F77)" → 26; 0 when it cannot be read.
  @visibleForTesting
  static int iosMajorVersion(String operatingSystemVersion) {
    final match = RegExp(r'(\d+)(\.\d+)*').firstMatch(operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  @override
  State<InkPasteButton> createState() => _InkPasteButtonState();
}

class _InkPasteButtonState extends State<InkPasteButton> {
  MethodChannel? _channel;

  void _created(int viewId) {
    _channel = MethodChannel('${InkPasteButton.viewType}/$viewId')
      ..setMethodCallHandler((call) async {
        if (call.method != 'pasted' || !mounted) return;
        widget.onPasted((call.arguments as String?)?.trim() ?? '');
      });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    return Semantics(
      identifier: 'paste.${widget.qaId}',
      container: true,
      child: SizedBox.fromSize(
        key: Key('paste.${widget.qaId}'),
        size: InkPasteButton.size,
        child: UiKitView(
          viewType: InkPasteButton.viewType,
          creationParams: {
            'foreground': colors.actionPrimaryFg.toARGB32(),
            'background': colors.actionPrimaryBg.toARGB32(),
            'cornerRadius': context.fuzzzyRadius.m,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _created,
        ),
      ),
    );
  }
}
