import 'package:flutter/widgets.dart';
import 'package:fuzzzy_ink/src/src.dart';

export 'check_draw.dart';
export 'chip_swap.dart';
export 'hero_glyph.dart';
export 'in_place_confirm_button.dart';
export 'ink_haptics.dart';
export 'lift_in.dart';
export 'row_tint.dart';
export 'settle_in.dart';

/// What the redesign's small responses may do here (DESIGN.md section 10).
///
/// Durations and curves always come from the kit's motion tokens
/// (`context.fuzzzyMotion`: fast 120 ms, standard 220 ms, slow 420 ms). The
/// only extra numbers are the delays and holds the design names, kept in
/// [InkMotionTiming].
abstract final class InkMotion {
  /// The phone asks for less motion (`MediaQuery.disableAnimations`): every
  /// response shows its final state at once.
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// The widget sits on a private screen ([SensitiveScreen]).
  static bool isPrivate(BuildContext context) => SensitiveScreen.isIn(context);

  /// Responses that move or glow (a row tint, a chip rising, the app lifting
  /// in, a step's arrow arriving): never on private screens.
  static bool allowsTravel(BuildContext context) =>
      !isReduced(context) && !isPrivate(context);

  /// In-place responses (a check drawing, a label swap, a countdown, a field
  /// turning red): allowed on private screens, off with reduced motion.
  static bool allowsInPlace(BuildContext context) => !isReduced(context);
}

/// The few timings DESIGN.md section 10 names that are not motion tokens.
abstract final class InkMotionTiming {
  /// A check starts drawing after the swap it confirms.
  static const checkDelay = Duration(milliseconds: 200);

  /// The step picture's check draws after its dot has started filling.
  static const stepCheckDelay = Duration(milliseconds: 240);

  /// The lock's shackle snaps after the glyph has started settling.
  static const shackleDelay = Duration(milliseconds: 140);

  /// The step picture's arrow arrives just after its dot starts filling.
  static const arrowDelay = Duration(milliseconds: 100);

  /// "Copied" and similar in-place confirmations stay this long.
  static const confirmHold = Duration(milliseconds: 1600);

  /// "Handed over" stays a little longer: the person just came back from the
  /// system's save dialog.
  static const handedOverHold = Duration(milliseconds: 2200);

  /// The new history row's tint fades over this long.
  static const rowTint = Duration(milliseconds: 1600);

  /// The Share sheet closes this long after its row confirmed a copy.
  static const sheetCloseAfterCopy = Duration(milliseconds: 700);
}
