import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The redesign's confirmation card: the kit toast for about 2.5 s, with
/// Fuzzz at its start for [castMoment] when Fuzzzy Cast is on and the
/// screen is not private (the "companion" option the kit toast does not
/// have yet). Screen readers hear the message.
void showInkToast(
  BuildContext context, {
  required String message,
  FuzzzyToastKind kind = FuzzzyToastKind.success,
  FuzzzyCastMoment? castMoment,
  Duration? duration,
  String? qaId,
}) {
  final overlay = Overlay.of(context);
  final moment = castMoment;
  final companion = moment != null && FuzzzyCastReaction.showsAt(context)
      ? FuzzzyCastReaction(
          moment: moment,
          placement: FuzzzyCastPlacement.toast,
        )
      : null;
  final shownFor = duration ?? (companion != null ? _withCompanion : _plain);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: ctx.fuzzzySpace.l,
      right: ctx.fuzzzySpace.l,
      bottom: ctx.fuzzzySpace.xxl + MediaQuery.of(ctx).padding.bottom,
      child: Material(
        type: MaterialType.transparency,
        child: FuzzzyToast(
          message: message,
          kind: kind,
          icon: companion,
          qaId: qaId,
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(shownFor, () {
    if (entry.mounted) entry.remove();
  });
}

const _plain = Duration(milliseconds: 2400);
const _withCompanion = Duration(milliseconds: 2800);
