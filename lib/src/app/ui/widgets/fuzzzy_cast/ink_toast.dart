import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The redesign's confirmation card: the kit toast for about 2.5 s, at the
/// top of the screen (DESIGN.md section 5: "Messages after actions appear
/// at the top as a small card"), with Fuzzz at its start for [castMoment]
/// when Fuzzzy Cast is on and the screen is not private (the "companion"
/// option the kit toast does not have yet). Screen readers hear the
/// message.
///
/// [overlay] is where it goes; by default the one above [context]. A caller
/// holding only the root navigator's overlay passes it, since
/// `Overlay.of` on the overlay's own context looks above it and found none —
/// "In X's history now." never showed after opening (QA 2026-10-26).
void showInkToast(
  BuildContext context, {
  required String message,
  FuzzzyToastKind kind = FuzzzyToastKind.success,
  FuzzzyCastMoment? castMoment,
  Duration? duration,
  String? qaId,
  OverlayState? overlay,
}) {
  final target = overlay ?? Overlay.of(context);
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
      top: ctx.fuzzzySpace.s + MediaQuery.paddingOf(ctx).top,
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
  target.insert(entry);
  Future<void>.delayed(shownFor, () {
    if (entry.mounted) entry.remove();
  });
}

const _plain = Duration(milliseconds: 2400);
const _withCompanion = Duration(milliseconds: 2800);
