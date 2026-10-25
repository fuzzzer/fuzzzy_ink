import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A kit button that confirms its own result in place: after [onPressed]
/// reports success it shows a drawn check and [confirmedLabel] ("Copied",
/// "Handed over") for [hold], at the same size, then returns. The change is
/// announced politely to screen readers and gives a light buzz on phones.
///
/// [onPressed] answers whether the real action happened (the clipboard
/// write, the system save): nothing is confirmed before that, and a `false`
/// leaves the button as it was. A second press restarts the confirmation.
/// Allowed on private screens: it is an in-place change.
class InPlaceConfirmButton extends StatefulWidget {
  const InPlaceConfirmButton({
    super.key,
    required this.label,
    required this.confirmedLabel,
    required this.onPressed,
    this.icon,
    this.variant = FuzzzyButtonVariant.secondary,
    this.size = FuzzzyButtonSize.m,
    this.hold = InkMotionTiming.confirmHold,
    this.qaId,
  });

  final String label;
  final String confirmedLabel;

  /// Null disables the button.
  final Future<bool> Function()? onPressed;
  final Widget? icon;
  final FuzzzyButtonVariant variant;
  final FuzzzyButtonSize size;
  final Duration hold;
  final String? qaId;

  @override
  State<InPlaceConfirmButton> createState() => _InPlaceConfirmButtonState();
}

class _InPlaceConfirmButtonState extends State<InPlaceConfirmButton> {
  Timer? _revert;
  int _confirmation = 0;
  bool _isConfirmed = false;
  bool _isBusy = false;

  @override
  void dispose() {
    _revert?.cancel();
    super.dispose();
  }

  Future<void> _press() async {
    final action = widget.onPressed;
    if (action == null || _isBusy) return;
    setState(() => _isBusy = true);
    final done = await action();
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (!done) return;

    _revert?.cancel();
    setState(() {
      _isConfirmed = true;
      _confirmation++;
    });
    unawaited(InkHaptics.light());
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.confirmedLabel,
        Directionality.of(context),
      ),
    );
    _revert = Timer(widget.hold, () {
      if (mounted) setState(() => _isConfirmed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final qaId = widget.qaId;
    final onPressed = widget.onPressed == null ? null : _press;

    // Both faces are laid out and the stack takes the larger, so the button
    // never changes size; only the shown face paints and takes taps.
    return IndexedStack(
      index: _isConfirmed ? 1 : 0,
      alignment: Alignment.center,
      sizing: StackFit.passthrough,
      children: [
        FuzzzyButton(
          label: widget.label,
          icon: widget.icon,
          variant: widget.variant,
          size: widget.size,
          qaId: qaId,
          onPressed: onPressed,
        ),
        FuzzzyButton(
          label: widget.confirmedLabel,
          icon: CheckDraw(
            key: ValueKey(_confirmation),
            size: context.fuzzzyIconSize.m,
          ),
          variant: widget.variant,
          size: widget.size,
          qaId: qaId == null ? null : '$qaId.confirmed',
          onPressed: onPressed,
        ),
      ],
    );
  }
}
